package com.sourcepoint.diagnose

import com.rickclephas.kmp.nativecoroutines.NativeCoroutines
import io.github.oshai.kotlinlogging.KotlinLogging
import io.ktor.http.*
import kotlinx.atomicfu.locks.SynchronizedObject
import kotlinx.atomicfu.locks.synchronized
import kotlinx.datetime.Clock
import kotlin.random.Random
import kotlin.time.ExperimentalTime
import kotlin.time.TimeSource

private val logger = KotlinLogging.logger {}

// primary interface for clients
interface DiagnoseEventHandler {
    // this will mark all incoming requests after this moment with this state
    @NativeCoroutines
    suspend fun setState(state: List<String>)

    // set current consent string
    @NativeCoroutines
    suspend fun setConsentString(consentString: String)

    @NativeCoroutines
    suspend fun urlReceived(url: String, method: String, headers: Collection<Pair<String, String>>): Boolean

    // TODO should this be in the api or just done in the background?
    // figure out if it's worth dumping the state and send it to the api
    @NativeCoroutines
    suspend fun dumpState()
}

// this class takes all actions from the application
@OptIn(ExperimentalTime::class)
class DiagnoseEventHandlerImpl(
    private val samplePercentage: Double?,
    private val vendorDatabase: VendorDatabase,
    private val ignoreDomains: Set<String>,
    private val client: DiagnoseClient,
    private val diagnoseDatabase: DiagnoseDatabase
) : DiagnoseEventHandler {

    private val start = Clock.System.now()
    private val lock = SynchronizedObject()

    // mutable state guarded by lock
    private val mark = TimeSource.Monotonic.markNow()
    private val random = Random(epochNanos(start))

    private fun getTimeNanos(): Long {
        synchronized(lock) {
            val elapsed = mark.elapsedNow()
            return epochNanos(start.plus(elapsed))
        }
    }

    // this will mark all incoming requests after this moment with this state
    override suspend fun setState(state: List<String>) {
        if (samplePercentage == null) {
            return
        }
        try {
            val timeNanos = getTimeNanos()
            diagnoseDatabase.setState(timeNanos, state)
        } catch (e: Throwable) {
            logger.error(e) { "error on urlReceived" }
        }
    }

    // set current consent string
    override suspend fun setConsentString(consentString: String) {
        if (samplePercentage == null) {
            return
        }
        try {
            val timeNanos = getTimeNanos()
            diagnoseDatabase.setConsentString(timeNanos, consentString)
        } catch (e: Throwable) {
            logger.error(e) { "error on urlReceived" }
        }
    }

    override suspend fun urlReceived(
        url: String,
        method: String,
        headers: Collection<Pair<String, String>>
    ): Boolean {
        var shouldReject = false;
        try {
            if (samplePercentage == null) {
                return shouldReject
            }
            val drop = synchronized(lock) {
                samplePercentage < random.nextDouble()
            }
            if (drop) {
                return shouldReject
            }
            val parsed = Url(url)
            val domain = parsed.host
            if (ignoreDomains.contains(domain)) {
                return shouldReject
            }
            val vendorId = vendorDatabase.getVendorId(domain) ?: return shouldReject
            val timeNanos = getTimeNanos()
            var valid = true
            val config = diagnoseDatabase.getLatestConfig()
            if (config.domainBlackList.contains(domain)) {
                valid = false
                shouldReject = true
            }
            // TODO checkblacklist
            diagnoseDatabase.addUrlEvent(timeNanos, vendorId, valid = valid, rejected = shouldReject)
        } catch (e: Throwable) {
            logger.error(e) { "error on urlReceived" }
        }
        // TODO determine whether this event needs to be rejected
        return shouldReject
    }

    // figure out if it's worth dumping the state and send it to the api
    override suspend fun dumpState() {
        // TODO every x events or y seconds we will try to dump all the state
        //      otherwise bailout
        try {
            val events = diagnoseDatabase.getAllEventsForSend()
            client.sendEvents(events)
        } catch (e: Throwable) {
            logger.error(e) { "error dumping state" }
            try {
                diagnoseDatabase.unmarkSendEvents()
            } catch (e: Throwable) {
                logger.error(e) { "error reverting state" }
            }
        }
    }
}
