package com.sourcepint.diagnose.storage

import com.sourcepoint.diagnose.storage.EventFlags
import com.sourcepoint.diagnose.storage.EventType
import com.sourcepoint.diagnose.storage.mkEventAdapter
import kotlin.test.Test
import kotlin.test.assertEquals

class EventFlagsTests {

    fun checkEncode(flags: EventFlags) {
        val adapter = mkEventAdapter()
        var encoded = adapter.flagsAdapter.encode(flags)
        val decoded = adapter.flagsAdapter.decode(encoded)
        assertEquals(flags, decoded)
    }

    @Test
    fun testFlags() {
        checkEncode(EventFlags(EventType.URL, true, false))
        checkEncode(EventFlags(EventType.URL, false, true))
        checkEncode(EventFlags(EventType.STATE, true, true))
        checkEncode(EventFlags(EventType.CONSENT_STRING, true, true))
    }
}