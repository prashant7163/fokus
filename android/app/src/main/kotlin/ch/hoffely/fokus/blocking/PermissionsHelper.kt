package ch.hoffely.fokus.blocking

import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings

/**
 * Permission status + settings-screen routing for the four PermissionKinds
 * (CONTRACTS §1): accessibility | usageStats | notifications | batteryExemption.
 *
 * Channel payload shape (consumed by the Dart BlockingAdapter, F-06):
 * `getPermissionStatus` returns `Map<String, Boolean>` keyed by kind.
 */
object PermissionsHelper {

    fun status(context: Context): Map<String, Boolean> = mapOf(
        "accessibility" to FokusAccessibilityService.isEnabled(context),
        "usageStats" to hasUsageStatsAccess(context),
        "notifications" to areNotificationsEnabled(context),
        "batteryExemption" to isBatteryExempt(context),
    )

    /** Opens the settings screen where [kind] can be granted. */
    fun settingsIntent(context: Context, kind: String): Intent = when (kind) {
        "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)

        "usageStats" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)

        "notifications" ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            } else {
                appDetailsIntent(context)
            }

        "batteryExemption" ->
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                .setData(Uri.parse("package:${context.packageName}"))

        else -> throw IllegalArgumentException("Unknown permission kind: $kind")
    }

    private fun appDetailsIntent(context: Context): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.parse("package:${context.packageName}"))

    private fun hasUsageStatsAccess(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE)
            as? AppOpsManager ?: return false
        @Suppress("DEPRECATION")
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun areNotificationsEnabled(context: Context): Boolean {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as? NotificationManager ?: return false
        return manager.areNotificationsEnabled()
    }

    private fun isBatteryExempt(context: Context): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE)
            as? PowerManager ?: return false
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }
}
