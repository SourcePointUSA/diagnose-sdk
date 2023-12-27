package com.sourcepoint.diagnose

interface VendorDatabaseLoader {
    fun loadLocalDatabase(): VendorDatabase?
    fun storeLocalDatabase(db: VendorDatabase)
}

// TODO add in header parsers
data class VendorData(val vendorId: String, val domain: String, val iabId: Int?)

interface VendorDatabase {
    val version: String

    fun getVendorData(domain: String): VendorData?

    fun export(consumer: (domain: String, vendorId: String, iabId: Int?) -> Unit)
}


class VendorDatabaseImpl(override val version: String, entries: Collection<VendorData>) : VendorDatabase {
    private val map = entries.associateBy { it.domain }

    override fun getVendorData(domain: String): VendorData? {
        return map[domain]
    }

    override fun export(consumer: (domain: String, vendorId: String, iabId: Int?) -> Unit) {
        for (entry in map.entries) {
            consumer(entry.key, entry.value.vendorId, entry.value.iabId)
        }
    }
}
