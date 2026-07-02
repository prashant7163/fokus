package ch.hoffely.fokus.blocking

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.telecom.TelecomManager
import android.view.accessibility.AccessibilityEvent

/**
 * Foreground-app detection (ARCHITECTURE intercept flow, step 1).
 *
 * Watches TYPE_WINDOW_STATE_CHANGED against the native [BlockedSetCache] —
 * zero channel round-trips on the hot path (< 200 ms intercept budget).
 * Config (event types, no window-content access) lives in
 * res/xml/accessibility_service_config.xml.
 *
 * Mechanism only: this class never decides session transitions; it reports
 * events, Dart decides (CONTRACTS §2).
 */
class FokusAccessibilityService : AccessibilityService() {

    private var lastInterceptPackage: String? = null
    private var lastInterceptAtMs: Long = 0L
    private val attemptTracker = AttemptTracker()

    @Volatile
    private var neverBlockable: Set<String> = emptySet()

    override fun onServiceConnected() {
        super.onServiceConnected()
        BlockedSetCache.ensureLoaded(this)
        neverBlockable = buildNeverBlockable(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString()
        val nowMs = System.currentTimeMillis()
        val shouldIntercept = InterceptDecider.shouldIntercept(
            packageName = packageName,
            nowMs = nowMs,
            session = BlockedSetCache.session,
            blockedSet = BlockedSetCache.blockedSet,
            neverBlockable = neverBlockable,
            passPackage = BlockedSetCache.passPackage,
            passEndEpochMs = BlockedSetCache.passEndEpochMs,
            lastInterceptPackage = lastInterceptPackage,
            lastInterceptAtMs = lastInterceptAtMs,
        )
        if (!shouldIntercept) return

        lastInterceptPackage = packageName
        lastInterceptAtMs = nowMs

        FokusEventBus.emitDistractionAttempt(this, packageName!!, nowMs)
        val attemptsInWindow = attemptTracker.record(nowMs)
        // Background-activity-start is permitted here: accessibility
        // services are system-bound (documented BAL exemption).
        InterceptActivity.launch(this, packageName, attemptsInWindow)
    }

    override fun onInterrupt() {
        // No continuous feedback to interrupt.
    }

    companion object {
        /** True when this service is enabled in system accessibility settings. */
        fun isEnabled(context: Context): Boolean {
            val expected = ComponentName(context, FokusAccessibilityService::class.java)
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            return enabled.split(':').any {
                ComponentName.unflattenFromString(it) == expected
            }
        }

        /**
         * Packages that are never intercepted (fokus-specs §3.2): FOKUS
         * itself, system UI, the default launcher, and the dialer.
         */
        fun buildNeverBlockable(context: Context): Set<String> {
            val result = mutableSetOf(
                context.packageName,
                "com.android.systemui",
                "android",
            )
            // Default launcher.
            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            context.packageManager
                .resolveActivity(home, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName
                ?.let(result::add)
            // Default dialer (currently ringing/active calls are never intercepted).
            (context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager)
                ?.defaultDialerPackage
                ?.let(result::add)
            return result
        }
    }
}
