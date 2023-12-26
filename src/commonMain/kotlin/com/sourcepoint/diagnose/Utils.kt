package com.sourcepoint.diagnose

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant

fun epochNanos(instant: Instant): Long {
    return instant.epochSeconds * 1_000_000_000 + instant.nanosecondsOfSecond
}

// TODO make into an interface
fun nowNanos(): Long {
    val now = Clock.System.now()
    return epochNanos(now)
}