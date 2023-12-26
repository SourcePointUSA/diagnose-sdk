package com.sourcepoint.diagnose.storage

import app.cash.sqldelight.ColumnAdapter
import kotlinx.collections.immutable.ImmutableList
import kotlinx.collections.immutable.ImmutableSet
import kotlinx.collections.immutable.persistentListOf
import kotlinx.collections.immutable.persistentSetOf
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationStrategy
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.SetSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json

@Serializable
data class DiagnoseConfig(
    val samplePercentage: Double?,
    @Serializable(with = ImmutableSetSerializer::class)
    val domainBlackList: ImmutableSet<String>,
    val eventMarker: Long?,
    val consentString: String?,
    @Serializable(with = ImmutableListSerializer::class)
    val clientState: ImmutableList<String>,
)

class ImmutableListSerializer : KSerializer<ImmutableList<String>> {
    private val serializer = ListSerializer(String.serializer())

    override val descriptor = serializer.descriptor

    override fun deserialize(decoder: Decoder): ImmutableList<String> {
        val deserialized = decoder.decodeSerializableValue(serializer)
        return persistentListOf<String>().addAll(deserialized)
    }

    override fun serialize(encoder: Encoder, value: ImmutableList<String>) {
        encoder.encodeSerializableValue(serializer, value)
    }
}

class ImmutableSetSerializer : KSerializer<ImmutableSet<String>> {
    private val serializer = SetSerializer(String.serializer())

    override val descriptor = serializer.descriptor

    override fun deserialize(decoder: Decoder): ImmutableSet<String> {
        val deserialized = decoder.decodeSerializableValue(serializer)
        return persistentSetOf<String>().addAll(deserialized)
    }

    override fun serialize(encoder: Encoder, value: ImmutableSet<String>) {
        encoder.encodeSerializableValue(serializer, value)
    }
}

fun mkConfigAdapter(): Config.Adapter {
    val configAdapter = DiagnoseConfigAdapter()
    return Config.Adapter(configAdapter)
}

class DiagnoseConfigAdapter : ColumnAdapter<DiagnoseConfig, String> {

    private val serializer: SerializationStrategy<DiagnoseConfig> = DiagnoseConfig.serializer()

    override fun decode(databaseValue: String): DiagnoseConfig {
        return Json.decodeFromString(databaseValue)
    }

    override fun encode(value: DiagnoseConfig): String {
        return Json.encodeToString(serializer, value)
    }
}