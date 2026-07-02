package ch.hoffely.fokus.blocking

/**
 * Native mirror of the session config pushed from Dart at session start
 * (CONTRACTS §1 `startSession`). The timer is wall-clock anchored via
 * [endEpochMs] — never tick-counted — so it survives process death and doze.
 *
 * Mechanism only: Kotlin never decides session transitions (CONTRACTS §2).
 */
data class NativeSessionConfig(
    val id: String,
    val endEpochMs: Long,
    val taskAnchor: String?,
    val strictMode: Boolean,
)
