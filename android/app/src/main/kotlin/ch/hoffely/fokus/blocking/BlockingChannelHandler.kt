package ch.hoffely.fokus.blocking

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Kotlin side of the BlockingAdapter contract (CONTRACTS §1).
 * MethodChannel `fokus/blocking` · EventChannel `fokus/events`.
 *
 * Payload shapes (Dart facade F-06 must match):
 * - getPermissionStatus → Map<String, Boolean> keyed by PermissionKind name
 * - requestPermission   ← {"kind": String}
 * - getInstalledApps    → List<Map> of {"packageName": String, "appName": String}
 * - setBlockedApps      ← {"packageNames": List<String>}
 * - startSession        ← {"id": String, "endEpochMs": int, "taskAnchor": String?,
 *                          "strictMode": bool}
 * - stopSession         ← {"sessionId": String}
 */
class BlockingChannelHandler(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getPermissionStatus" ->
                    result.success(PermissionsHelper.status(activity))

                "requestPermission" -> {
                    val kind = call.argument<String>("kind")
                        ?: return result.error(ERROR, "missing kind", null)
                    activity.startActivity(
                        PermissionsHelper.settingsIntent(activity, kind),
                    )
                    result.success(null)
                }

                "getInstalledApps" -> result.success(installedApps())

                "setBlockedApps" -> {
                    val packages = call.argument<List<String>>("packageNames")
                        ?: return result.error(ERROR, "missing packageNames", null)
                    BlockedSetCache.setBlockedApps(activity, packages)
                    result.success(null)
                }

                "startSession" -> {
                    val id = call.argument<String>("id")
                        ?: return result.error(ERROR, "missing id", null)
                    val endEpochMs = call.argument<Number>("endEpochMs")?.toLong()
                        ?: return result.error(ERROR, "missing endEpochMs", null)
                    val config = NativeSessionConfig(
                        id = id,
                        endEpochMs = endEpochMs,
                        taskAnchor = call.argument<String>("taskAnchor"),
                        strictMode = call.argument<Boolean>("strictMode") ?: false,
                    )
                    BlockedSetCache.startSession(activity, config)
                    SessionForegroundService.start(activity, restored = false)
                    result.success(null)
                }

                "stopSession" -> {
                    val sessionId = call.argument<String>("sessionId")
                        ?: return result.error(ERROR, "missing sessionId", null)
                    // D-013 P1-C: Dart decides liveness, always. Decision is
                    // pure (StopDecision) so it is JVM-tested; a mismatch emits
                    // a `stopMismatch` diagnostic carrying both ids (D-013
                    // sanctions this diagnostic; CONTRACTS §1 addendum flagged
                    // in the F-22 summary). Stop is unconditional — never a
                    // silent no-op.
                    val live = BlockedSetCache.session?.id
                    val decision = StopDecision.decide(live, sessionId)
                    if (decision.emitMismatch) {
                        FokusEventBus.emitStopMismatch(
                            requestedId = sessionId,
                            liveId = live!!,
                        )
                    }
                    if (decision.stop) {
                        BlockedSetCache.clearSession(activity)
                        SessionForegroundService.stop(activity)
                    }
                    result.success(null)
                }

                "ackEvents" -> {
                    // D-013 P1-A: Dart acks the highest journal seq it has
                    // durably written; entries at or below it are dropped.
                    val upToSeq = call.argument<Number>("upToSeq")?.toLong()
                        ?: return result.error(ERROR, "missing upToSeq", null)
                    FokusEventBus.ackJournal(activity, upToSeq)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error(ERROR, e.message, null)
        }
    }

    /**
     * Launchable apps, excluding FOKUS itself. App picker metadata only —
     * icons are resolved natively by InterceptActivity (F-05); picker icons
     * arrive with F-11 if needed.
     */
    private fun installedApps(): List<Map<String, String>> {
        val pm = activity.packageManager
        val launchable = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val activities = pm.queryIntentActivities(
            launchable,
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        return activities
            .asSequence()
            .map { it.activityInfo }
            .filter { it.packageName != activity.packageName }
            .distinctBy { it.packageName }
            .map {
                mapOf(
                    "packageName" to it.packageName,
                    "appName" to it.loadLabel(pm).toString(),
                )
            }
            .sortedBy { it["appName"]?.lowercase() }
            .toList()
    }

    companion object {
        private const val ERROR = "fokus_blocking"
        private const val METHOD_CHANNEL = "fokus/blocking"
        private const val EVENT_CHANNEL = "fokus/events"

        /** Wire both channels onto [engine]. Called from MainActivity. */
        fun register(activity: Activity, engine: FlutterEngine) {
            BlockedSetCache.ensureLoaded(activity)
            FokusEventBus.attachContext(activity)
            val messenger = engine.dartExecutor.binaryMessenger
            MethodChannel(messenger, METHOD_CHANNEL)
                .setMethodCallHandler(BlockingChannelHandler(activity))
            EventChannel(messenger, EVENT_CHANNEL)
                .setStreamHandler(FokusEventBus)
        }
    }
}
