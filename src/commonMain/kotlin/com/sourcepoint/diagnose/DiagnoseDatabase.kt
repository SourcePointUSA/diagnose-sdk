package com.sourcepoint.diagnose

import app.cash.sqldelight.db.SqlDriver
import com.sourcepoint.diagnose.storage.*
import kotlinx.atomicfu.atomic
import kotlinx.collections.immutable.persistentListOf
import kotlinx.collections.immutable.persistentSetOf

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
    fun unmarkSendEvents()
}

class DiagnoseDatabaseImpl(driver: SqlDriver) : DiagnoseDatabase {
    private val storage = DiagnoseStorage.invoke(driver, mkConfigAdapter(), mkEventAdapter(), mkStateStringAdapter())
    private val queries = storage.diagnoseStorageQueries
    private val configVersion = "1.0"
    private val defaultConfig = defaultConfig()
    private val configCache = atomic(Pair(0L, defaultConfig))

    override fun addConfig(config: DiagnoseConfig) {
        val nanos = nowNanos()
        val row = Config(nanos, configVersion, config)
        queries.addConfig(row)
    }

    private fun defaultConfig(): DiagnoseConfig {
        return DiagnoseConfig(null, persistentSetOf(), null, null, persistentListOf())
    }

    private fun getOrCreateConfig(): DiagnoseConfig {
        val cached = configCache.value
        val latestTime = queries.getLatestConfigTime(configVersion).executeAsOneOrNull()
        if (latestTime == null) {
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
        // TODO getOrCreate state
        val stateId = 0L
        val flags = EventFlags(EventType.STATE, false, false)
        val event = EventV1(timeNanos, flags, null, null, stateId)
        queries.insertEvent(event)
    }

    override fun setConsentString(timeNanos: Long, string: String) {
        // TODO getOrCreate
        val consentStringId = 0L
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
            val events = queries.getAllEventsForSend().executeAsList()
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
                    .map { it.stateStringId to it.value_ }.toMap()
                val vendorMap = queries.selectVendorById(vendorIds).executeAsList()
                    .map { it.vendorId to it }.toMap()
                var eventMarker = 0L;
                // set high water mark
                val result = mutableListOf<SendEvent>()
                var state = listOf<String>()
                for (event in events) {
                    eventMarker = event.eventTime
                    when (event.flags.type) {
                        EventType.CONSENT_STRING -> continue
                        EventType.STATE -> state = stateMap[event.stateStringId!!]!!.value
                        EventType.URL -> {
                            val vendor = vendorMap.get(event.vendorId!!)!!
                            val sendEvent = SendEvent(
                                state,
                                event.eventTime / 1000L,
                                event.vendorId!!,
                                vendor.domain,
                                rejected = event.flags.rejected,
                                valid = event.flags.valid
                            )
                            result.add(sendEvent)
                        }
                    }
                }
                val config = getOrCreateConfig()
                config.copy(eventMarker = eventMarker)
                queries.addConfig(Config(nowNanos(), configVersion, config))
                result
            }
        }
    }

    override fun unmarkSendEvents() {
        storage.transaction {
            val config = getOrCreateConfig()
            config.copy(eventMarker = null)
            queries.addConfig(Config(nowNanos(), configVersion, config))
        }
    }

    override fun loadLocalDatabase(): VendorDatabase? {
        val vendors = queries.getVendorDatabase().executeAsList()
        val map = HashMap<String, String>()
        for (vendor in vendors) {
            map[vendor.domain] = vendor.vendorId
        }
        // TODO get from config
        val version = "1.0"
        return VendorDatabaseImpl(version, map)
    }

    // TODO insert from high water mark
    override fun storeLocalDatabase(db: VendorDatabase) {
    }
}
