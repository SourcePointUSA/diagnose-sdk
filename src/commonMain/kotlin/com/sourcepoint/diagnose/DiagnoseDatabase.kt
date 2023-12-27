package com.sourcepoint.diagnose

import app.cash.sqldelight.db.SqlDriver
import com.sourcepoint.diagnose.storage.*
import kotlinx.atomicfu.atomic
import kotlinx.collections.immutable.persistentListOf
import kotlinx.collections.immutable.persistentSetOf
import kotlinx.collections.immutable.toImmutableList

data class SendEvent(
    val state: List<String>,
    val timeMs: Long,
    val vendorId: String,
    val domain: String,
    val valid: Boolean,
    val rejected: Boolean
)

interface DiagnoseDatabase : VendorDatabaseLoader {
    fun getLatestConfig(): DiagnoseConfig
    fun addConfig(config: DiagnoseConfig)
    fun setState(timeNanos: Long, state: List<String>)
    fun setConsentString(timeNanos: Long, string: String)
    fun addUrlEvent(timeNanos: Long, vendorId: String, valid: Boolean, rejected: Boolean)
    fun getAllEventsForSend(): List<SendEvent>
    fun clearOldEvents()
    fun unmarkSendEvents()
}

class DiagnoseDatabaseImpl(driver: SqlDriver, private val monotonicClock: MonotonicClock) :
    DiagnoseDatabase {
    private val storage = DiagnoseStorage.invoke(driver, mkConfigAdapter(), mkEventAdapter(), mkStateStringAdapter())
    private val queries = storage.diagnoseStorageQueries
    private val configVersion = "1.0"
    private val defaultConfig = defaultConfig()
    private val configCache = atomic(Pair(0L, defaultConfig))

    override fun addConfig(config: DiagnoseConfig) {
        val nanos = monotonicClock.nowNanos()
        val row = Config(nanos, configVersion, config)
        queries.addConfig(row)
        queries.clearOldConfigs()
    }

    private fun defaultConfig(): DiagnoseConfig {
        return DiagnoseConfig("000", null, persistentSetOf(), null, null, persistentListOf())
    }

    private fun getOrCreateConfig(): DiagnoseConfig {
        val cached = configCache.value
        val latestTime = queries.getLatestConfigTime(configVersion).executeAsOne()
        if (latestTime.MAX == null) {
            return cached.second
        }
        if (cached.first == latestTime.MAX) {
            return cached.second
        }
        return storage.transactionWithResult {
            val config = queries.getLatestConfig(configVersion).executeAsOne()
            configCache.value = Pair(config.configTime, config.value_)
            config.value_
        }
    }

    override fun getLatestConfig(): DiagnoseConfig {
        return getOrCreateConfig()
    }

    override fun setState(timeNanos: Long, state: List<String>) {
        val wrapper = StringList(state.toImmutableList())
        val stateId = queries.upsertStateString(StateString(timeNanos, wrapper)).executeAsOne()
        val flags = EventFlags(EventType.STATE, false, false)
        val event = EventV1(timeNanos, flags, null, null, stateId)
        queries.insertEvent(event)
    }

    override fun setConsentString(timeNanos: Long, string: String) {
        val consentStringId = queries.upsertConsentString(ConsentString(timeNanos, 1L, string)).executeAsOne()
        val flags = EventFlags(EventType.CONSENT_STRING, false, false)
        val event = EventV1(timeNanos, flags, null, consentStringId, null)
        queries.insertEvent(event)
    }

    override fun addUrlEvent(timeNanos: Long, vendorId: String, valid: Boolean, rejected: Boolean) {
        val flags = EventFlags(EventType.URL, rejected = rejected, valid = valid)
        val event = EventV1(timeNanos, flags, vendorId, null, null)
        queries.insertEvent(event)
    }

    override fun getAllEventsForSend(): List<SendEvent> {
        return storage.transactionWithResult {
            val events = queries.getEventsOnOrBefore(Long.MAX_VALUE).executeAsList()
            if (events.isEmpty()) {
                listOf()
            } else {
                val vendorIds = mutableSetOf<String>()
                val stateStringIds = mutableSetOf<Long>()
                for (event in events) {
                    when (event.flags.type) {
                        EventType.CONSENT_STRING -> continue
                        EventType.STATE -> stateStringIds.add(event.stateStringId!!)
                        EventType.URL -> vendorIds.add(event.vendorId!!)
                    }
                }
                val stateMap = queries.selectStateStringById(stateStringIds).executeAsList()
                    .associate { it.stateStringId to it.value_ }
                val vendorMap = queries.selectVendorById(vendorIds).executeAsList().associateBy { it.vendorId }
                var eventMarker = 0L
                // set high watermark
                val result = mutableListOf<SendEvent>()
                var state = listOf<String>()
                for (event in events) {
                    eventMarker = event.eventTime
                    when (event.flags.type) {
                        EventType.CONSENT_STRING -> continue
                        EventType.STATE -> state = stateMap[event.stateStringId!!]!!.value
                        EventType.URL -> {
                            val vendor = vendorMap[event.vendorId!!]!!
                            val sendEvent = SendEvent(
                                state,
                                event.eventTime / 1000L,
                                event.vendorId,
                                vendor.domain,
                                rejected = event.flags.rejected,
                                valid = event.flags.valid
                            )
                            result.add(sendEvent)
                        }
                    }
                }
                val config = getOrCreateConfig().copy(eventMarker = eventMarker)
                addConfig(config)
                result
            }
        }
    }

    override fun clearOldEvents() {
        storage.transaction {
            val config = getOrCreateConfig()
            val marker = config.eventMarker
            if (marker != null) {
                val events = queries.getEventsOnOrBefore(marker).executeAsList()
                var latestConsentString = 0L
                var latestStateString = 0L
                for (event in events) {
                    when (event.flags.type) {
                        EventType.CONSENT_STRING -> latestConsentString = event.eventTime
                        EventType.STATE -> latestStateString = event.eventTime
                        else -> {}
                    }
                }
                queries.clearEvents(marker, listOf(latestConsentString, latestStateString))
                queries.clearUnusedConsentStrings()
                queries.clearUnusedStates()
                // clear event marker
                addConfig(config.copy(eventMarker = null))
            }
        }
    }

    override fun unmarkSendEvents() {
        storage.transaction {
            val config = getOrCreateConfig().copy(eventMarker = null)
            addConfig(config)
        }
    }

    override fun loadLocalDatabase(): VendorDatabase {
        val (version, vendors) = storage.transactionWithResult {
            val vendors = queries.getVendorDatabase().executeAsList()
            val config = getOrCreateConfig()
            Pair(config.databaseVersion, vendors)
        }
        val entries = ArrayList<VendorData>()
        for (vendor in vendors) {
            entries.add(VendorData(vendor.vendorId, vendor.domain, vendor.iabId?.toInt()))
        }
        return VendorDatabaseImpl(version, entries)
    }

    // TODO insert from high watermark
    // TODO this will fail if there are updates to domain
    override fun storeLocalDatabase(db: VendorDatabase) {
        storage.transactionWithResult {
            db.export { domain: String, vendorId: String, iabId: Int? ->
                queries.insertVendor(
                    Vendor(
                        vendorId,
                        1L,
                        domain,
                        iabId?.toLong()
                    )
                )
            }
        }
        val config = getOrCreateConfig().copy(databaseVersion = db.version)
        addConfig(config)
    }
}
