package com.sourcepoint.diagnose

import com.sourcepoint.api.v1.api.DefaultApi
import com.sourcepoint.api.v1.model.ClientConfig
import com.sourcepoint.api.v1.model.EventLarge
import com.sourcepoint.api.v1.model.RecordEventsRequest
import com.sourcepoint.api.v1.model.VendorDbLarge

interface DiagnoseClient {
    suspend fun getConfig(): Result<ClientConfig>

    suspend fun getVendorDatabase(): Result<VendorDatabase>

    suspend fun sendEvents(events: List<SendEvent>): Result<Unit>
}

// simple helper for swift integration
fun mkDefaultApi(url: String): DefaultApi {
    return DefaultApi(url)
}

class DiagnoseClientImpl(private val api: DefaultApi, private val clientId: String, private val appId: String) :
    DiagnoseClient {

    override suspend fun getConfig(): Result<ClientConfig> {
        return try {
            val resp = api.getConfig(clientId, appId, "")
            Result.success(resp.body())
        } catch (e: Throwable) {
            Result.failure(e)
        }
    }

    override suspend fun getVendorDatabase(): Result<VendorDatabase> {
        return try {
            val resp = api.getDbLarge()
            convertDb(resp.body())
        } catch (e: Throwable) {
            Result.failure(e)
        }
    }

    override suspend fun sendEvents(events: List<SendEvent>): Result<Unit> {
        return try {
            val largeEvents = convertEvents(events)
            if (events.isNotEmpty()) {
                val req = RecordEventsRequest(clientId, appId, largeEvents)
                api.recordEvents(req)
            }
            Result.success(Unit)
        } catch (e: Throwable) {
            Result.failure(e)
        }
    }
}

suspend fun loadDatabase(client: DiagnoseClient, loader: VendorDatabaseLoader): VendorDatabase {
    val badVersion = "000"
    // start with empty db
    var db: VendorDatabase = VendorDatabaseImpl(badVersion, HashMap())
    // TODO log error
    // check local store
    val localDb = loader.loadLocalDatabase().getOrNull()
    if (localDb != null) {
        db = localDb
    }
    val configRes = client.getConfig()
    val config = configRes.getOrElse {
        // TODO log error
        ClientConfig(badVersion, false, 0.0, badVersion)
    }
    // call sourcepoint if config is stale
    if (config.version != db.version && config.version != badVersion) {
        // TODO log error
        val clientDb = client.getVendorDatabase().getOrNull()
        if (clientDb != null) {
            // write back to local store
            loader.storeLocalDatabase(clientDb)
            // TODO log error
            db = clientDb
        }
    }
    return db
}

fun convertDb(db: VendorDbLarge): Result<VendorDatabase> {
    val version = when (val maybeVersion = db.version) {
        null -> return Result.failure(RuntimeException("unset version"))
        "" -> return Result.failure(RuntimeException("empty version"))
        else -> maybeVersion
    }
    val map = HashMap<String, String>()
    for (row in db.rows.orEmpty()) {
        val id = row.id.orEmpty()
        val domain = row.domain.orEmpty()
        val kind = row.kind?.or(-1)
        if (id.isEmpty() || domain.isEmpty() || kind == -1) {
            // TODO return error on bad row?
            continue
        }
        map[domain] = id
    }
    val res = VendorDatabaseImpl(version, map)
    return Result.success(res)
}

fun convertEvents(events: List<SendEvent>): List<EventLarge> {
    val newEvents = events.map { e ->
        // TODO pass rejected
        EventLarge(
            e.timeMs.toDouble(), e.domain, e.valid, e.state
        )
    }
    return newEvents
}