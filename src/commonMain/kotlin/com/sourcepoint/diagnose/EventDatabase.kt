package com.sourcepoint.diagnose

data class SendEvent(
    val state: List<String>,
    val timeMs: Long,
    val vendorId: String,
    val domain: String,
    val valid: Boolean,
    val rejected: Boolean
)

interface EventDatabase {
    suspend fun insertEvent(event: Event): Result<Unit>
    suspend fun getAllEventsForSend(): Result<List<SendEvent>>
    suspend fun unmarkSendEvents(): Result<Unit>
}
