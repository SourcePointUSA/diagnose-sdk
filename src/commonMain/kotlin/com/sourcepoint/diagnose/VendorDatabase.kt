package com.sourcepoint.diagnose

interface VendorDatabaseLoader {
    fun loadLocalDatabase(): VendorDatabase?
    fun storeLocalDatabase(db: VendorDatabase)
}

interface VendorDatabase {
    val version: String

    // TODO take url and return more vendorId and url type and header parsers
    fun getVendorId(domain: String): String?

    fun export(consumer: (domain: String, vendorId: String, iabId: Int?) -> Unit)
}

data class VendorData(val vendorId: String, val domain: String, val iabId: Int?)

class VendorDatabaseImpl(override val version: String, entries: Collection<VendorData>) : VendorDatabase {
    private val map = entries.associateBy { it.domain }

    override fun getVendorId(domain: String): String? {
        return map[domain]?.vendorId
    }

    override fun export(consumer: (domain: String, vendorId: String, iabId: Int?) -> Unit) {
        for (entry in map.entries) {
            consumer(entry.key, entry.value.vendorId, entry.value.iabId)
        }
    }
}
