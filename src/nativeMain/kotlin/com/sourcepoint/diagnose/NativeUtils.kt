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
    try {
        return client.getConfig()
    } catch (e: Throwable) {
        logger.error(e) { "error loading config" }
        return ClientConfig(badVersion, false, 0.0, badVersion, listOf())
    }
}

suspend fun loadDatabase(
    config: ClientConfig,
    client: DiagnoseClient,
    loader: VendorDatabaseLoader
): VendorDatabase {
    // start with empty db
    var db: VendorDatabase = VendorDatabaseImpl(badVersion, HashMap())
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
        val diagnoseDatabase = DiagnoseDatabaseImpl(driver)
        val vendorDatabase = loadDatabase(config, client, diagnoseDatabase)
        // TODO get from config
        val samplePercentage = 0.5
        return DiagnoseEventHandlerImpl(samplePercentage, vendorDatabase, setOf(), client, diagnoseDatabase)
    } catch (e: Throwable) {
        // TODO log errors
        return NullEventHandler()
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
