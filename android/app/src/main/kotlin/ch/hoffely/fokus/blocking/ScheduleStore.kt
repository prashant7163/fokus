package ch.hoffely.fokus.blocking

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray

/**
 * Prefs-persisted mirror of the enabled schedules (synced from Dart via
 * `syncSchedules`, F-13/D-022) plus one-shot skip markers set from the
 * reminder notification's "Skip" action. Survives process death and reboot;
 * WorkManager re-arms from here.
 */
object ScheduleStore {

    private const val PREFS_NAME = "fokus_schedules"
    private const val KEY_SCHEDULES = "schedules_json"
    private const val KEY_SKIP_PREFIX = "skip_once_" // + scheduleId → occurrenceMs

    fun save(context: Context, schedules: List<NativeSchedule>) {
        val arr = JSONArray()
        schedules.forEach { arr.put(it.toJson()) }
        prefs(context).edit().putString(KEY_SCHEDULES, arr.toString()).apply()
    }

    fun load(context: Context): List<NativeSchedule> {
        val raw = prefs(context).getString(KEY_SCHEDULES, null) ?: return emptyList()
        return runCatching {
            val arr = JSONArray(raw)
            (0 until arr.length()).map {
                NativeSchedule.fromJson(arr.getJSONObject(it))
            }
        }.getOrDefault(emptyList())
    }

    fun byId(context: Context, id: Int): NativeSchedule? =
        load(context).firstOrNull { it.id == id }

    /** "Skip" tapped on the reminder: veto exactly [occurrenceMs] once. */
    fun markSkipOnce(context: Context, scheduleId: Int, occurrenceMs: Long) {
        prefs(context).edit()
            .putLong(KEY_SKIP_PREFIX + scheduleId, occurrenceMs)
            .apply()
    }

    fun skipMarker(context: Context, scheduleId: Int): Long? {
        val value = prefs(context).getLong(KEY_SKIP_PREFIX + scheduleId, -1L)
        return if (value == -1L) null else value
    }

    fun clearSkipMarker(context: Context, scheduleId: Int) {
        prefs(context).edit().remove(KEY_SKIP_PREFIX + scheduleId).apply()
    }

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
