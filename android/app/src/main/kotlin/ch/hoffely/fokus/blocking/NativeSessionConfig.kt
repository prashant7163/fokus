package ch.hoffely.fokus.blocking

/**
 * Native mirror of the session config pushed from Dart at session start
 * (CONTRACTS §1 `startSession`). The timer is wall-clock anchored via
 * [endEpochMs] — never tick-counted — so it survives process death and doze.
 *
 * [startedEpochMs] and [recoveryEnabled] arrived with F-13 (D-022): the start
 * anchor lets Dart synthesize the DB row for sessions a schedule auto-started
 * natively; [recoveryEnabled] is the preset flag — when false the intercept
 * hides its "I'm stuck" CTA and the proactive hint.
 *
 * Mechanism only: Kotlin never decides session transitions (CONTRACTS §2).
 */
data class NativeSessionConfig(
    val id: String,
    val endEpochMs: Long,
    val taskAnchor: String?,
    val strictMode: Boolean,
    val startedEpochMs: Long = 0L,
    val recoveryEnabled: Boolean = true,
)
