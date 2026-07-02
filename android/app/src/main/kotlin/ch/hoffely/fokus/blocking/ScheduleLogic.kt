package ch.hoffely.fokus.blocking

import org.json.JSONArray
import org.json.JSONObject
import java.time.DayOfWeek
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/**
 * A schedule as synced from Dart (CONTRACTS §1 `syncSchedules`, F-13/D-022):
 * preset config + ISO weekdays (1 = Monday … 7 = Sunday) + local wall-clock
 * start time. Policy (what to run, when) is decided in Dart; this native
 * mirror only computes occurrences and arms WorkManager.
 */
data class NativeSchedule(
    val id: Int,
    val presetName: String,
    val packages: List<String>,
    val durationMin: Int,
    val strictMode: Boolean,
    val recoveryEnabled: Boolean,
    val daysOfWeek: Set<Int>,
    val startLocalTime: String, // "HH:mm"
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("presetName", presetName)
        put("packages", JSONArray(packages))
        put("durationMin", durationMin)
        put("strictMode", strictMode)
        put("recoveryEnabled", recoveryEnabled)
        put("daysOfWeek", JSONArray(daysOfWeek.toList()))
        put("startLocalTime", startLocalTime)
    }

    companion object {
        fun fromJson(json: JSONObject): NativeSchedule = NativeSchedule(
            id = json.getInt("id"),
            presetName = json.getString("presetName"),
            packages = json.getJSONArray("packages").let { arr ->
                (0 until arr.length()).map { arr.getString(it) }
            },
            durationMin = json.getInt("durationMin"),
            strictMode = json.getBoolean("strictMode"),
            recoveryEnabled = json.getBoolean("recoveryEnabled"),
            daysOfWeek = json.getJSONArray("daysOfWeek").let { arr ->
                (0 until arr.length()).map { arr.getInt(it) }.toSet()
            },
            startLocalTime = json.getString("startLocalTime"),
        )

        fun fromMap(map: Map<String, Any?>): NativeSchedule = NativeSchedule(
            id = (map["id"] as Number).toInt(),
            presetName = map["presetName"] as String,
            packages =
                (map["packages"] as List<*>).map { it as String },
            durationMin = (map["durationMin"] as Number).toInt(),
            strictMode = map["strictMode"] as Boolean,
            recoveryEnabled = map["recoveryEnabled"] as Boolean,
            daysOfWeek =
                (map["daysOfWeek"] as List<*>).map { (it as Number).toInt() }
                    .toSet(),
            startLocalTime = map["startLocalTime"] as String,
        )
    }
}

/**
 * Pure occurrence math — JVM-tested (CONVENTIONS bar). Local wall-clock
 * semantics: "the next 07:30 on a Mon/Wed" in whatever zone the device is in
 * when the computation runs; a zone change re-arms on the next sync/fire.
 */
object ScheduleLogic {

    /** Reminder notification lead time (fokus-specs §3.7). */
    const val REMINDER_LEAD_MIN = 5L

    /**
     * The next occurrence of [schedule] strictly AFTER [nowMs], as epoch ms
     * in [zone]. Returns null for a schedule with no weekdays.
     */
    fun nextOccurrenceMs(
        schedule: NativeSchedule,
        nowMs: Long,
        zone: ZoneId,
    ): Long? {
        if (schedule.daysOfWeek.isEmpty()) return null
        val time = LocalTime.parse(schedule.startLocalTime)
        val now = LocalDateTime.ofInstant(
            java.time.Instant.ofEpochMilli(nowMs),
            zone,
        )
        for (offset in 0..7L) {
            val day = now.toLocalDate().plusDays(offset)
            if (day.dayOfWeek.isoValue !in schedule.daysOfWeek) continue
            val candidate = LocalDateTime.of(day, time)
            if (candidate.isAfter(now)) {
                return candidate.atZone(zone).toInstant().toEpochMilli()
            }
        }
        return null // unreachable with ≥1 weekday, kept for totality
    }

    private val DayOfWeek.isoValue: Int get() = value // ISO-8601: Mon=1…Sun=7

    /**
     * Whether the auto-start should proceed when its worker fires:
     * skipped-once occurrences and a session already live both veto (a
     * schedule must never clobber a running session — fokus-specs §3.7
     * "never traps" + CONTRACTS single-live-session model).
     */
    fun shouldStart(
        skipMarker: Long?,
        occurrenceMs: Long,
        liveSessionId: String?,
    ): Boolean = skipMarker != occurrenceMs && liveSessionId == null
}
