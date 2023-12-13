package com.sourcepoint.diagnose

import io.ktor.http.*
import kotlinx.atomicfu.locks.SynchronizedObject
import kotlinx.atomicfu.locks.synchronized
import kotlinx.collections.immutable.ImmutableList
import kotlinx.collections.immutable.toImmutableList
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlin.random.Random
import kotlin.time.TimeSource


sealed class Event {
    data class ConsentStringEvent(
        val timeNanos: Long, val consentString: String
    ) : Event()

    data class StateEvent(
        val timeNanos: Long, val state: ImmutableList<String>
    ) : Event()

    data class UrlEvent(
        val timeNanos: Long,
        val vendorId: String,
        val domain: String,
        val url: String,
        val method: String,
        val headers: ImmutableList<Pair<String, String>>,
    ) : Event()
}

interface DiagnoseEventHandler {
    // this will mark all incoming requests after this moment with this state
    suspend fun setState(state: Collection<String>)

    // set current consent string
    suspend fun setConsentString(consentString: String)

    suspend fun urlReceived(url: String, method: String, headers: Collection<Pair<String, String>>): Boolean

    // TODO should this be in the api or just done in the background?
    // figure out if it's worth dumping the state and send it to the api
    suspend fun dumpState()
}

// want to use nanos for ordering of events in database
fun epochNanos(instant: Instant): Long {
    return instant.epochSeconds * 1_000_000_000 + instant.nanosecondsOfSecond
}

// this class takes all actions from the application
class DiagnoseEventHandlerImpl(
    private val samplePercentage: Double?,
    private val vendorDatabase: VendorDatabase,
    private val ignoreDomains: Set<String>,
    private val client: DiagnoseClient,
    private val eventDatabase: EventDatabase
) : DiagnoseEventHandler {

    private val start = Clock.System.now()
    private val lock = SynchronizedObject()

    // mutable state guarded by lock
    private val mark = TimeSource.Monotonic.markNow()
    private val random = Random(epochNanos(start))

    suspend fun <E : Event> mkEvent(f: (Long) -> E) {
        val event = synchronized(lock) {
            val elapsed = mark.elapsedNow()
            // TODO nanos
            val timeNanos = epochNanos(start.plus(elapsed))
            f(timeNanos)
        }
        // TODO log error
        eventDatabase.insertEvent(event)
    }

    // this will mark all incoming requests after this moment with this state
    override suspend fun setState(state: Collection<String>) {
        if (samplePercentage == null) {
            return
        }
        val stateImm = state.toImmutableList()
        mkEvent { timeNanos: Long -> Event.StateEvent(timeNanos, stateImm) }
    }

    // set current consent string
    override suspend fun setConsentString(consentString: String) {
        if (samplePercentage == null) {
            return
        }
        mkEvent { timeNanos: Long -> Event.ConsentStringEvent(timeNanos, consentString) }
    }

    override suspend fun urlReceived(
        url: String,
        method: String,
        headers: Collection<Pair<String, String>>
    ): Boolean {
        var shouldReject = false;
        if (samplePercentage == null) {
            return shouldReject
        }
        val drop = synchronized(lock) {
            samplePercentage < random.nextDouble()
        }
        if (drop) {
            return shouldReject
        }
        val parsed: Url
        try {
            parsed = Url(url)
        } catch (e: Throwable) {
            // TODO log
            return shouldReject
        }
        val domain = parsed.host
        if (ignoreDomains.contains(domain)) {
            return shouldReject
        }
        val vendorId = vendorDatabase.getVendorId(domain)
        if (vendorId == null) {
            return shouldReject
        }
        val headersImm = headers.toImmutableList()
        mkEvent { timeNanos: Long ->
            Event.UrlEvent(
                timeNanos,
                vendorId,
                domain,
                url,
                method,
                headersImm
            )
        }
        // TODO determine whether this event needs to be rejected
        return shouldReject
    }

    // figure out if it's worth dumping the state and send it to the api
    override suspend fun dumpState() {
        // TODO every x events or y seconds we will try to dump all the state
        //      otherwise bailout
        try {
            val events = eventDatabase.getAllEventsForSend().getOrThrow()
            try {
                client.sendEvents(events).getOrThrow()
            } catch (e: Throwable) {
                // TODO log error
                eventDatabase.unmarkSendEvents()
                return
            }
        } catch (e: Throwable) {
            // TODO log error
            return
        }
    }
}
