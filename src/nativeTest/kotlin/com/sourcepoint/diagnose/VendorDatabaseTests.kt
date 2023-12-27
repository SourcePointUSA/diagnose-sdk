package com.sourcepoint.diagnose

import app.cash.sqldelight.driver.native.inMemoryDriver
import com.sourcepoint.diagnose.storage.DiagnoseStorage
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class VendorDatabaseTests {

    private fun mkDatabase(vendorDb: VendorDatabase): DiagnoseDatabase {
        val schema = DiagnoseStorage.Schema
        val driver = inMemoryDriver(schema)
        val clock = MonotonicClockImpl()
        val db = DiagnoseDatabaseImpl(driver, clock)
        db.storeLocalDatabase(vendorDb)
        return db
    }

    private fun mkVendorDb(): VendorDatabase {
        val data = listOf(
            VendorData("1", "d1.com", null),
            VendorData("2", "d2.com", null),
        )
        return VendorDatabaseImpl("1", data)
    }

    @Test
    fun testUpsert() {
        val vendorDb = mkVendorDb()
        val db = mkDatabase(vendorDb)
        db.setConsentString(1, "c1")
        db.setConsentString(2, "c1")
        db.setState(3, listOf("s1"))
        db.setState(4, listOf("s1"))
    }

    @Test
    fun testFlow() {
        val vendorDb = mkVendorDb()
        val db = mkDatabase(vendorDb)
        var events = db.getAllEventsForSend()
        assertEquals(0, events.size)
        assertNull(db.getLatestConfig().eventMarker)
        db.setConsentString(1, "c1")
        db.setState(2, listOf("s1", "s2"))
        db.addUrlEvent(3, "1", false, false)
        assertNull(db.getLatestConfig().eventMarker)
        events = db.getAllEventsForSend()
        assertEquals(3, db.getLatestConfig().eventMarker)
        assertEquals(1, events.size)
        db.clearOldEvents()
        assertNull(db.getLatestConfig().eventMarker)
        events = db.getAllEventsForSend()
        assertEquals(0, events.size)
    }
}