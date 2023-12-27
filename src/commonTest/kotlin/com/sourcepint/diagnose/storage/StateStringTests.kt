package com.sourcepint.diagnose.storage

import com.sourcepoint.diagnose.storage.StringList
import com.sourcepoint.diagnose.storage.mkStateStringAdapter
import kotlinx.collections.immutable.ImmutableList
import kotlinx.collections.immutable.toImmutableList
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals

class StateStringTests {

    fun check(value: List<String>) {
        val adapter = mkStateStringAdapter()
        val stringList = StringList(value.toImmutableList())
        val encoded = adapter.value_Adapter.encode(stringList)
        val decoded = adapter.value_Adapter.decode(encoded)
        assertContentEquals(value, decoded.value.toList())
    }

    @Test
    fun testEncode() {
        check(listOf())
        check(listOf("a"))
        check(listOf("b"))
    }
}