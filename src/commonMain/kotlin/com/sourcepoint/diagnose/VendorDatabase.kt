package com.sourcepoint.diagnose

interface VendorDatabaseLoader {
    suspend fun loadLocalDatabase(): Result<VendorDatabase?>
    suspend fun storeLocalDatabase(db: VendorDatabase): Result<Unit>
}

interface VendorDatabase {
    val version: String

    // TODO take url and return more vendorId and url type and header parsers
    fun getVendorId(domain: String): String?
}

class VendorDatabaseImpl(override val version: String, private val map: HashMap<String, String>) : VendorDatabase {

    override fun getVendorId(domain: String): String? {
        return map[domain]
    }
}
