package ch.hoffely.fokus.blocking

/**
 * Pure decision logic for SessionForegroundService — what to do given the
 * cached session and the wall clock. No Android dependencies so it is JVM
 * unit-testable (CONVENTIONS testing bar).
 *
 * The timer is wall-clock anchored on [NativeSessionConfig.endEpochMs]
 * (never tick-counted), so restore after process death / reboot is the same
 * computation as a normal tick.
 */
object SessionServicePlan {

    const val MINUTE_MS: Long = 60_000L

    sealed interface Plan {
        /** No session in the cache — nothing to run. */
        object NoSession : Plan

        /** Session end is in the past — stop; Dart owns the completed transition. */
        object Expired : Plan

        /** Keep the foreground notification alive and tick again later. */
        data class Run(
            val remainingMinutes: Int,
            val nextTickDelayMs: Long,
        ) : Plan
    }

    fun planFor(session: NativeSessionConfig?, nowMs: Long): Plan {
        if (session == null) return Plan.NoSession
        val remainingMs = session.endEpochMs - nowMs
        if (remainingMs <= 0) return Plan.Expired
        return Plan.Run(
            remainingMinutes = remainingMinutes(remainingMs),
            nextTickDelayMs = nextTickDelayMs(remainingMs),
        )
    }

    /** Ceiling — the notification never shows "0 min" while time remains. */
    fun remainingMinutes(remainingMs: Long): Int =
        ((remainingMs + MINUTE_MS - 1) / MINUTE_MS).toInt()

    /**
     * Delay until the displayed minute value next changes (or the session
     * ends) — ticks align to the session's own minute boundary, so the
     * notification is updated exactly when its text would change.
     */
    fun nextTickDelayMs(remainingMs: Long): Long {
        val toBoundary = remainingMs % MINUTE_MS
        return if (toBoundary == 0L) MINUTE_MS else toBoundary
    }
}
