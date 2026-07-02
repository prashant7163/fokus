package ch.hoffely.fokus.blocking

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Pure, Android-free core of the attempt journal (D-013 P1-A). Operates on the
 * raw JSON string held in prefs and the current seq counter; the Android glue
 * ([AttemptJournal]) only reads/writes those two prefs values. Kept pure so the
 * at-least-once / ack / replay semantics are JVM-unit-testable without
 * Robolectric (CONVENTIONS testing bar).
 */
object JournalCore {

    const val TYPE_DISTRACTION = "distractionAttempt"
    const val TYPE_RECOVERY = "recoveryRequested"

    /** Result of an append: the new entries JSON and the seq just assigned. */
    data class Appended(val entriesJson: String, val assignedSeq: Long)

    fun appendDistraction(
        entriesJson: String?,
        nextSeq: Long,
        packageName: String,
        tsEpochMs: Long,
    ): Appended = append(entriesJson, nextSeq) { entry ->
        entry.put("type", TYPE_DISTRACTION)
        entry.put("pkg", packageName)
        entry.put("ts", tsEpochMs)
    }

    fun appendRecovery(
        entriesJson: String?,
        nextSeq: Long,
        tsEpochMs: Long,
    ): Appended = append(entriesJson, nextSeq) { entry ->
        entry.put("type", TYPE_RECOVERY)
        entry.put("ts", tsEpochMs)
    }

    /** Parsed entries in seq order, each an event-shaped map (`{type, seq, …}`). */
    fun entries(entriesJson: String?): List<Map<String, Any?>> {
        val array = parse(entriesJson)
        val out = ArrayList<Map<String, Any?>>(array.length())
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            out.add(obj.toEventMap())
        }
        return out
    }

    /** Drops every entry with `seq <= upToSeq`; returns the surviving JSON. */
    fun ack(entriesJson: String?, upToSeq: Long): String {
        val array = parse(entriesJson)
        val kept = JSONArray()
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            if (obj.optLong("seq", Long.MIN_VALUE) > upToSeq) kept.put(obj)
        }
        return kept.toString()
    }

    private inline fun append(
        entriesJson: String?,
        nextSeq: Long,
        fill: (JSONObject) -> Unit,
    ): Appended {
        val array = parse(entriesJson)
        val entry = JSONObject().apply {
            put("seq", nextSeq)
            fill(this)
        }
        array.put(entry)
        return Appended(array.toString(), nextSeq)
    }

    private fun parse(entriesJson: String?): JSONArray {
        if (entriesJson == null) return JSONArray()
        return try {
            JSONArray(entriesJson)
        } catch (_: Exception) {
            JSONArray()
        }
    }

    private fun JSONObject.toEventMap(): Map<String, Any?> {
        val map = LinkedHashMap<String, Any?>()
        map["type"] = optString("type")
        map["seq"] = optLong("seq")
        if (has("pkg")) map["pkg"] = optString("pkg")
        if (has("ts")) map["ts"] = optLong("ts")
        return map
    }
}

/**
 * Persisted native journal for high-volume, must-never-drop events
 * (`distractionAttempt`, `recoveryRequested`) — D-013 P1-A.
 *
 * The reviewer's finding: the in-memory [FokusEventBus] deque is bounded at 16
 * and silently drops the 17th buffered event, losing "the product hypothesis"
 * data (fokus-specs §3.2). The D-013 ruling splits buffering:
 *  - restore-critical events (`sessionRestored`, `permissionLost`) keep the
 *    tiny in-memory deque in [FokusEventBus];
 *  - `distractionAttempt` / `recoveryRequested` go here: an unbounded (within a
 *    session), SharedPreferences-backed append log, replayed to Dart on attach
 *    and cleared only on explicit ack.
 *
 * Delivery is **at-least-once**: entries replay on every Dart attach and clear
 * only when Dart acks the highest seq it has durably written. A crash after
 * replay but before ack simply replays again — Dart's `pkg|ts` idempotency
 * guard collapses the duplicate. Nothing is lost even across a crash mid-replay.
 *
 * The seq counter ([KEY_NEXT_SEQ]) stays globally monotonic across sessions, so
 * a stale in-flight ack from a previous session can never match a new session's
 * entries. All logic lives in the pure [JournalCore]; this object is only the
 * prefs read/write glue. Access is main-thread; `synchronized` adds defence.
 */
object AttemptJournal {

    private const val PREFS_NAME = "fokus_attempt_journal"
    private const val KEY_ENTRIES = "entries"
    private const val KEY_NEXT_SEQ = "next_seq"

    const val TYPE_DISTRACTION = JournalCore.TYPE_DISTRACTION
    const val TYPE_RECOVERY = JournalCore.TYPE_RECOVERY

    fun appendDistraction(context: Context, packageName: String, tsEpochMs: Long): Long =
        synchronized(this) {
            val prefs = prefs(context)
            val result = JournalCore.appendDistraction(
                prefs.getString(KEY_ENTRIES, null),
                prefs.getLong(KEY_NEXT_SEQ, 0L),
                packageName,
                tsEpochMs,
            )
            write(prefs, result)
            result.assignedSeq
        }

    fun appendRecoveryRequested(context: Context, tsEpochMs: Long): Long =
        synchronized(this) {
            val prefs = prefs(context)
            val result = JournalCore.appendRecovery(
                prefs.getString(KEY_ENTRIES, null),
                prefs.getLong(KEY_NEXT_SEQ, 0L),
                tsEpochMs,
            )
            write(prefs, result)
            result.assignedSeq
        }

    fun entries(context: Context): List<Map<String, Any?>> = synchronized(this) {
        JournalCore.entries(prefs(context).getString(KEY_ENTRIES, null))
    }

    fun ack(context: Context, upToSeq: Long) = synchronized(this) {
        val prefs = prefs(context)
        val kept = JournalCore.ack(prefs.getString(KEY_ENTRIES, null), upToSeq)
        prefs.edit().putString(KEY_ENTRIES, kept).apply()
    }

    /** Clears entries (session start/stop). Seq counter stays monotonic. */
    fun clear(context: Context) = synchronized(this) {
        prefs(context).edit().remove(KEY_ENTRIES).apply()
    }

    private fun write(prefs: SharedPreferences, result: JournalCore.Appended) {
        prefs.edit()
            .putString(KEY_ENTRIES, result.entriesJson)
            .putLong(KEY_NEXT_SEQ, result.assignedSeq + 1)
            .apply()
    }

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
