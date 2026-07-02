package ch.hoffely.fokus.blocking

/**
 * Sliding-window counter of distraction attempts (fokus-specs §3.2):
 * ≥ [HINT_THRESHOLD] attempts within [WINDOW_MS] surface the proactive
 * recovery hint on the intercept screen.
 *
 * Pure Kotlin, JVM unit-testable. One instance lives in
 * [FokusAccessibilityService]; the 5-minute window makes cross-session
 * bleed-through self-limiting.
 */
class AttemptTracker(
    private val windowMs: Long = WINDOW_MS,
    private val maxEntries: Int = MAX_ENTRIES,
) {

    private val timestamps = ArrayDeque<Long>()

    /** Record an attempt at [nowMs] and return the count inside the window. */
    fun record(nowMs: Long): Int {
        timestamps.addLast(nowMs)
        prune(nowMs)
        return timestamps.size
    }

    fun countWithin(nowMs: Long): Int {
        prune(nowMs)
        return timestamps.size
    }

    private fun prune(nowMs: Long) {
        while (timestamps.isNotEmpty() &&
            (timestamps.first() <= nowMs - windowMs || timestamps.size > maxEntries)
        ) {
            timestamps.removeFirst()
        }
    }

    companion object {
        const val WINDOW_MS: Long = 5 * 60_000L
        const val HINT_THRESHOLD: Int = 3
        private const val MAX_ENTRIES: Int = 32

        /** True when the intercept screen should show the proactive hint. */
        fun shouldShowHint(attemptsInWindow: Int): Boolean =
            attemptsInWindow >= HINT_THRESHOLD
    }
}
