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
 * - grantAppPass        ← {"packageName": String, "endEpochMs": int}
 * - getAppIcons         ← {"packageNames": List<String>}
 *                       → Map<String, ByteArray> (PNG, 96 px; missing apps omitted)
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

                "grantAppPass" -> {
                    // F-08 "need one app" (non-strict): Dart decides the pass
                    // (policy — duration, strict gating); this only records it.
                    // The decider ignores the pass once nowMs passes its end.
                    val packageName = call.argument<String>("packageName")
                        ?: return result.error(ERROR, "missing packageName", null)
                    val endEpochMs = call.argument<Number>("endEpochMs")?.toLong()
                        ?: return result.error(ERROR, "missing endEpochMs", null)
                    BlockedSetCache.grantAppPass(activity, packageName, endEpochMs)
                    result.success(null)
                }

                "getAppIcons" -> {
                    // F-11 UI polish (D-019): launcher icons as PNG bytes for
                    // the home hero / config / active-session rows. Missing
                    // or uninstalled packages are simply omitted.
                    val packages = call.argument<List<String>>("packageNames")
                        ?: return result.error(ERROR, "missing packageNames", null)
                    result.success(appIcons(packages))
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

    /** Launcher icons rendered to 96 px PNG bytes, keyed by package name. */
    private fun appIcons(packageNames: List<String>): Map<String, ByteArray> {
        val pm = activity.packageManager
        val out = mutableMapOf<String, ByteArray>()
        for (pkg in packageNames.distinct()) {
            try {
                val drawable = pm.getApplicationIcon(pkg)
                val size = 96
                val bitmap = android.graphics.Bitmap.createBitmap(
                    size,
                    size,
                    android.graphics.Bitmap.Config.ARGB_8888,
                )
                val canvas = android.graphics.Canvas(bitmap)
                drawable.setBounds(0, 0, size, size)
                drawable.draw(canvas)
                val stream = java.io.ByteArrayOutputStream()
                bitmap.compress(
                    android.graphics.Bitmap.CompressFormat.PNG,
                    100,
                    stream,
                )
                bitmap.recycle()
                out[pkg] = stream.toByteArray()
            } catch (_: PackageManager.NameNotFoundException) {
                // Uninstalled since — omitted; Dart falls back to a glyph.
            }
        }
        return out
    }

    /**
     * Launchable apps, excluding FOKUS itself. App picker metadata only —
     * icons arrive separately via getAppIcons (F-11, D-019).
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
