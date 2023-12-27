package com.sourcepoint.diagnose

import kotlinx.atomicfu.locks.SynchronizedObject
import kotlinx.atomicfu.locks.synchronized
import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import kotlin.time.ExperimentalTime
import kotlin.time.TimeSource

fun epochNanos(instant: Instant): Long {
    return instant.epochSeconds * 1_000_000_000 + instant.nanosecondsOfSecond
}

interface MonotonicClock {
    fun nowNanos(): Long
}

@OptIn(ExperimentalTime::class)
class MonotonicClockImpl : MonotonicClock {
    private val start = Clock.System.now()
    private val lock = SynchronizedObject()

    // mutable state guarded by lock
    private val mark = TimeSource.Monotonic.markNow()
    private var last = epochNanos(start)

    override fun nowNanos(): Long {
        synchronized(lock) {
            val elapsed = mark.elapsedNow()
            var nanos = epochNanos(start.plus(elapsed))
            if (last == nanos) {
                nanos += 1
            }
            last = nanos
            return nanos
        }
    }
}
