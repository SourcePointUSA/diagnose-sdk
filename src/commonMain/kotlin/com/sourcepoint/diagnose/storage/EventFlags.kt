package com.sourcepoint.diagnose.storage

import app.cash.sqldelight.ColumnAdapter

// NB: don't change order as we use ordinal
enum class EventType {
    URL,
    CONSENT_STRING,
    STATE,
}

data class EventFlags(val type: EventType, val rejected: Boolean, val valid: Boolean)

fun mkEventAdapter(): EventV1.Adapter {
    val flagsAdapter = FlagsAdapter()
    return EventV1.Adapter(flagsAdapter)
}

private fun shiftBoolean(x: Boolean, shift: Int): Long {
    return (if (x) 1L else 0L) shl shift
}

private fun unshiftBoolean(value: Long, shift: Int): Boolean {
    return ((value shr shift) and 0x1) != 0L
}

// TODO test
class FlagsAdapter : ColumnAdapter<EventFlags, Long> {
    private val eventTypes = EventType.values()

    override fun encode(value: EventFlags): Long {
        var result = 0L
        result = result or value.type.ordinal.toLong()
        result = result or shiftBoolean(value.valid, 8)
        result = result or shiftBoolean(value.rejected, 9)
        return result
    }

    override fun decode(databaseValue: Long): EventFlags {
        val type = eventTypes[(databaseValue and 0xff).toInt()]
        val valid = unshiftBoolean(databaseValue, 8)
        val rejected = unshiftBoolean(databaseValue, 9)
        return EventFlags(type, rejected, valid)
    }
}