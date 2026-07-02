package ch.hoffely.fokus.blocking

import android.content.Context
import android.content.SharedPreferences

/**
 * Native-side cache of the blocked set + active session config.
 *
 * Synced from Dart at session start (ARCHITECTURE: no channel round-trip on
 * the hot path) and persisted to SharedPreferences so the accessibility
 * service and BootReceiver (F-04) can re-arm after process death without
 * the Flutter engine running.
 */
object BlockedSetCache {

    private const val PREFS_NAME = "fokus_blocking"
    private const val KEY_BLOCKED = "blocked_packages"
    private const val KEY_SESSION_ID = "session_id"
    private const val KEY_SESSION_END = "session_end_epoch_ms"
    private const val KEY_SESSION_ANCHOR = "session_task_anchor"
    private const val KEY_SESSION_STRICT = "session_strict_mode"

    @Volatile
    var blockedSet: Set<String> = emptySet()
        private set

    @Volatile
    var session: NativeSessionConfig? = null
        private set

    @Volatile
    private var loaded = false

    /** Idempotent; call before first read (service connect, channel attach). */
    fun ensureLoaded(context: Context) {
        if (loaded) return
        synchronized(this) {
            if (loaded) return
            val prefs = prefs(context)
            blockedSet = prefs.getStringSet(KEY_BLOCKED, emptySet())?.toSet()
                ?: emptySet()
            val id = prefs.getString(KEY_SESSION_ID, null)
            session = if (id == null) {
                null
            } else {
                NativeSessionConfig(
                    id = id,
                    endEpochMs = prefs.getLong(KEY_SESSION_END, 0L),
                    taskAnchor = prefs.getString(KEY_SESSION_ANCHOR, null),
                    strictMode = prefs.getBoolean(KEY_SESSION_STRICT, false),
                )
            }
            loaded = true
        }
    }

    fun setBlockedApps(context: Context, packageNames: List<String>) {
        ensureLoaded(context)
        blockedSet = packageNames.toSet()
        prefs(context).edit()
            .putStringSet(KEY_BLOCKED, blockedSet)
            .apply()
    }

    fun startSession(context: Context, config: NativeSessionConfig) {
        ensureLoaded(context)
        session = config
        prefs(context).edit()
            .putString(KEY_SESSION_ID, config.id)
            .putLong(KEY_SESSION_END, config.endEpochMs)
            .putString(KEY_SESSION_ANCHOR, config.taskAnchor)
            .putBoolean(KEY_SESSION_STRICT, config.strictMode)
            .apply()
    }

    fun clearSession(context: Context) {
        ensureLoaded(context)
        session = null
        prefs(context).edit()
            .remove(KEY_SESSION_ID)
            .remove(KEY_SESSION_END)
            .remove(KEY_SESSION_ANCHOR)
            .remove(KEY_SESSION_STRICT)
            .apply()
    }

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
