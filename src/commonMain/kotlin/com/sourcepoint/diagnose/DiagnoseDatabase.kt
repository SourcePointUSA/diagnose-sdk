package com.sourcepoint.diagnose

import app.cash.sqldelight.db.SqlDriver
import com.sourcepoint.diagnose.storage.*
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
    private val storage = DiagnoseStorage.invoke(driver, mkConfigAdapter(), mkEventAdapter())
    private val queries = storage.diagnoseStorageQueries
    private val configVersion = "1.0"

    override fun addConfig(config: DiagnoseConfig) {
        val nanos = nowNanos()
        val row = Config(nanos, configVersion, config)
        queries.addConfig(row)
    }

    private fun defaultConfig(): DiagnoseConfig {
        return DiagnoseConfig(null, persistentSetOf(), null, null, persistentListOf())
    }

    private fun getOrCreateConfig(): DiagnoseConfig {
        val config = queries.getLatestConfig(configVersion).executeAsOneOrNull()
        return config ?: defaultConfig()
    }

    override fun getLatestConfig(): DiagnoseConfig {
        return getOrCreateConfig()
    }

    override fun setState(timeNanos: Long, state: List<String>) {
        TODO("Not yet implemented")
    }

    override fun addUrlEvent(timeNanos: Long, vendorId: String, valid: Boolean, rejected: Boolean) {
        TODO("Not yet implemented")
    }

    override fun setConsentString(timeNanos: Long, string: String) {
        TODO("Not yet implemented")
    }

    override fun getAllEventsForSend(): List<SendEvent> {
        return storage.transactionWithResult {
            val events = queries.getAllEventsForSend().executeAsList()
            if (events.isEmpty()) {
                listOf()
            } else {
                var eventMarker = 0L;
                // set high water mark
                val config = getOrCreateConfig()
                config.copy(eventMarker = eventMarker)
                queries.addConfig(Config(nowNanos(), configVersion, config))
                listOf()
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
