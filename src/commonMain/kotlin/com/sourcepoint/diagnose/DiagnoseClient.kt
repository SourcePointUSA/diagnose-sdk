package com.sourcepoint.diagnose

import com.sourcepoint.api.v1.api.DefaultApi
import com.sourcepoint.api.v1.model.ClientConfig
import com.sourcepoint.api.v1.model.EventLarge
import com.sourcepoint.api.v1.model.RecordEventsRequest
import com.sourcepoint.api.v1.model.VendorDbLarge

interface DiagnoseClient {
    suspend fun getConfig(): ClientConfig

    suspend fun getVendorDatabase(): VendorDatabase

    suspend fun sendEvents(events: List<SendEvent>)
}

class DiagnoseClientImpl(
    private val api: DefaultApi,
    private val clientId: String,
    private val appId: String,
    private val regionId: String
) :
    DiagnoseClient {

    override suspend fun getConfig(): ClientConfig {
        val resp = api.getConfig(clientId, appId, regionId)
        return resp.body()
    }

    override suspend fun getVendorDatabase(): VendorDatabase {
        val resp = api.getDbLarge()
        return convertDb(resp.body())
    }

    override suspend fun sendEvents(events: List<SendEvent>) {
        if (events.isNotEmpty()) {
            val largeEvents = convertEvents(events)
            val req = RecordEventsRequest(clientId, appId, largeEvents)
            api.recordEvents(req)
        }
    }
}

private fun convertDb(db: VendorDbLarge): VendorDatabase {
    val version = db.version.trim()
    if (version.isEmpty()) {
        throw RuntimeException("empty version")
    }
    val map = HashMap<String, String>()
    for (row in db.rows) {
        val id = row.id
        val domain = row.domain
        val kind = row.kind
        if (id.isEmpty() || domain.isEmpty() || kind == -1) {
            // TODO return error on bad row?
            continue
        }
        map[domain] = id
    }
    return VendorDatabaseImpl(version, map)
}

private fun convertEvents(events: List<SendEvent>): List<EventLarge> {
    val newEvents = events.map { e ->
        EventLarge(
            e.timeMs.toDouble(), e.domain, e.valid, e.rejected, e.state,
        )
    }
    return newEvents
}