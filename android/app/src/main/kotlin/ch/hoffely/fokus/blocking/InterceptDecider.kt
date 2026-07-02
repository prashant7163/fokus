package ch.hoffely.fokus.blocking

/**
 * Pure intercept decision logic — the hot path of the blocking core.
 * No Android dependencies so it is JVM unit-testable (CONVENTIONS testing bar).
 */
object InterceptDecider {

    /** Same-app re-intercept suppression window. */
    const val DEBOUNCE_MS: Long = 1_500L

    /**
     * True when a foreground change to [packageName] must trigger the
     * intercept screen.
     *
     * Rules (fokus-specs §3.2):
     * - only while a session is active ([nowMs] before its endEpochMs),
     * - only for apps in the blocked set,
     * - never for [neverBlockable] packages (FOKUS itself, system UI,
     *   dialer, default launcher),
     * - debounced per package so one app switch produces one intercept.
     */
    fun shouldIntercept(
        packageName: String?,
        nowMs: Long,
        session: NativeSessionConfig?,
        blockedSet: Set<String>,
        neverBlockable: Set<String>,
        lastInterceptPackage: String?,
        lastInterceptAtMs: Long,
    ): Boolean {
        if (packageName.isNullOrEmpty()) return false
        if (session == null || nowMs >= session.endEpochMs) return false
        if (packageName in neverBlockable) return false
        if (packageName !in blockedSet) return false
        val debounced = packageName == lastInterceptPackage &&
            nowMs - lastInterceptAtMs < DEBOUNCE_MS
        return !debounced
    }
}
