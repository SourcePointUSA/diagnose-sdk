package com.sourcepoint.diagnose.storage

import app.cash.sqldelight.ColumnAdapter
import kotlinx.collections.immutable.ImmutableList
import kotlinx.collections.immutable.persistentListOf
import kotlinx.collections.immutable.toImmutableList

data class StringList(val value: ImmutableList<String>)

fun mkStateStringAdapter(): StateString.Adapter {
    val adapter = StringListAdapter()
    return StateString.Adapter(adapter)
}

private class StringListAdapter : ColumnAdapter<StringList, String> {
    override fun decode(databaseValue: String): StringList {
        // TODO unescape commas
        val list =
            if (databaseValue.isEmpty()) persistentListOf() else databaseValue.split(",").toImmutableList()
        return StringList(list)
    }

    override fun encode(value: StringList): String {
        // TODO escape commas
        return value.value.joinToString(",") { it.trim() }
    }
}