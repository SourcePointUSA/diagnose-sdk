package com.sourcepoint.diagnose

import app.cash.sqldelight.driver.native.NativeSqliteDriver
import app.cash.sqldelight.driver.native.inMemoryDriver
import com.rickclephas.kmp.nativecoroutines.NativeCoroutines
import com.sourcepoint.api.v1.api.DefaultApi
import com.sourcepoint.api.v1.model.ClientConfig
import com.sourcepoint.diagnose.storage.DiagnoseStorage
import io.github.oshai.kotlinlogging.KotlinLogging

private const val badVersion = "000"
private val logger = KotlinLogging.logger {}

private suspend fun loadConfigOrDefault(client: DiagnoseClient): ClientConfig {
    return try {
        client.getConfig()
    } catch (e: Throwable) {
        logger.error(e) { "error loading config" }
        ClientConfig(badVersion, false, 0.0, badVersion, listOf())
    }
}

suspend fun loadDatabase(
    config: ClientConfig,
    client: DiagnoseClient,
    loader: VendorDatabaseLoader
): VendorDatabase {
    // start with empty db
    var db: VendorDatabase = VendorDatabaseImpl(badVersion, listOf())
    // check local store
    try {
        val localDb = loader.loadLocalDatabase()
        if (localDb != null) {
            db = localDb
        }
    } catch (e: Throwable) {
        logger.error(e) { "error loading local database" }
    }
    // call sourcepoint if config is stale
    if (config.version != db.version && config.version != badVersion) {
        try {
            val clientDb = client.getVendorDatabase()
            // write back to local store
            loader.storeLocalDatabase(clientDb)
            db = clientDb
        } catch (e: Throwable) {
            logger.error(e) { "error loading remote database" }
        }
    }
    return db
}

// helper for native code to generate main interface with no complex constructors
@NativeCoroutines
suspend fun mkDefaultEventHandler(
    apiUrl: String,
    databaseName: String?,
    clientId: String,
    appId: String,
    // TODO make regionId optional
    regionId: String,
): DiagnoseEventHandler {
    try {
        val api = DefaultApi(apiUrl)
        val schema = DiagnoseStorage.Schema
        val driver = if (databaseName == null) {
            inMemoryDriver(schema)
        } else {
            NativeSqliteDriver(schema, databaseName)
        }
        val client = DiagnoseClientImpl(api, clientId, appId, regionId)
        val config = loadConfigOrDefault(client)
        val clock = MonotonicClockImpl()
        val diagnoseDatabase = DiagnoseDatabaseImpl(driver, clock)
        val vendorDatabase = loadDatabase(config, client, diagnoseDatabase)
        // TODO need a way to evaluate tcf strings in swift or natively in kotlin
        val consentManager = NullConsentManager()
        return DiagnoseEventHandlerImpl(
            vendorDatabase,
            setOf(),
            client,
            diagnoseDatabase,
            clock,
            consentManager
        )
    } catch (e: Throwable) {
        // TODO log errors
        return NullEventHandler()
    }
}

class NullConsentManager : ConsentManager {
    override fun isIabConsented(iabId: Int, consentString: String): Boolean {
        return false
    }
}

class NullEventHandler : DiagnoseEventHandler {
    override suspend fun urlReceived(url: String, method: String, headers: Collection<Pair<String, String>>): Boolean {
        return false
    }

    override suspend fun setConsentString(consentString: String) {
    }

    override suspend fun setState(state: List<String>) {

    }

    override suspend fun dumpState() {

    }
}
