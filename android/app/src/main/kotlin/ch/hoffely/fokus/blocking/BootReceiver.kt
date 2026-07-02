package ch.hoffely.fokus.blocking

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-arms an active session after reboot (ARCHITECTURE resilience
 * requirements). Reads the SharedPreferences-backed [BlockedSetCache] —
 * no Flutter engine needed — and restarts [SessionForegroundService] if the
 * session is still live on the wall clock. Expired sessions are left for
 * Dart to reconcile on next app launch.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        BlockedSetCache.ensureLoaded(context)
        val plan = SessionServicePlan.planFor(
            BlockedSetCache.session,
            System.currentTimeMillis(),
        )
        if (plan is SessionServicePlan.Plan.Run) {
            SessionForegroundService.start(context, restored = true)
        }
    }
}
