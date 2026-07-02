package ch.hoffely.fokus.blocking

import android.content.Context
import io.flutter.plugin.common.EventChannel

/**
 * Holds the `fokus/events` EventChannel sink so native components (the
 * accessibility service, session service, intercept) can push BlockingEvents
 * to Dart. Event names/payloads per CONTRACTS §1.
 *
 * Two-tier buffering (D-013 P1-A):
 *  - **Restore-critical** events (`sessionRestored`, `permissionLost`) are rare
 *    and must never be missed; they stay in a small in-memory deque here,
 *    replayed the moment a sink attaches. With the high-volume traffic moved
 *    off this channel (below), they can no longer be evicted.
 *  - **High-volume** events (`distractionAttempt`, `recoveryRequested`) carry
 *    "the product hypothesis" data (fokus-specs §3.2) and MUST NOT drop. They
 *    are persisted to [AttemptJournal] (SharedPreferences), unbounded within a
 *    session, replayed to Dart on attach, and cleared only on explicit ack.
 *    Delivery is at-least-once; Dart's `pkg|ts` guard dedupes replays.
 *
 * Hot-path events other than the above (`interceptShown`) remain best-effort:
 * if the engine is not attached they are dropped (informational only).
 *
 * All calls happen on the main thread (channel callbacks, service handler,
 * broadcast receiver, accessibility callback) — no extra synchronization needed
 * for the sink; the journal adds its own guard.
 */
object FokusEventBus : EventChannel.StreamHandler {

    private const val PENDING_LIMIT = 16

    private var sink: EventChannel.EventSink? = null
    private val pending = ArrayDeque<Map<String, Any?>>()

    /** Application context for journal access; set at channel registration. */
    @Volatile
    private var appContext: Context? = null

    fun attachContext(context: Context) {
        appContext = context.applicationContext
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        if (events == null) return
        // Restore-critical deque first (order within a boot does not matter to
        // Dart — every handler is idempotent), then the persisted journal so
        // no distraction attempt is lost across a process death.
        while (pending.isNotEmpty()) {
            events.success(pending.removeFirst())
        }
        appContext?.let { ctx ->
            for (entry in AttemptJournal.entries(ctx)) {
                events.success(entry)
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // --- high-volume, journalled (never drop) -----------------------------

    /**
     * Persists the attempt to the journal, then delivers live if a sink is
     * attached. The journal is the source of truth: if the engine is down the
     * entry waits there and replays on attach; if it is up, Dart also acks the
     * seq, clearing it. Either way the attempt lands exactly once in the DB.
     */
    fun emitDistractionAttempt(context: Context, packageName: String, tsEpochMs: Long) {
        val seq = AttemptJournal.appendDistraction(context, packageName, tsEpochMs)
        sink?.success(
            mapOf(
                "type" to AttemptJournal.TYPE_DISTRACTION,
                "seq" to seq,
                "pkg" to packageName,
                "ts" to tsEpochMs,
            ),
        )
    }

    fun emitRecoveryRequested(context: Context, tsEpochMs: Long) {
        val seq = AttemptJournal.appendRecoveryRequested(context, tsEpochMs)
        sink?.success(
            mapOf(
                "type" to AttemptJournal.TYPE_RECOVERY,
                "seq" to seq,
                "ts" to tsEpochMs,
            ),
        )
    }

    /** Dart acks the highest journal seq it has durably written (P1-A). */
    fun ackJournal(context: Context, upToSeq: Long) =
        AttemptJournal.ack(context, upToSeq)

    // --- restore-critical, in-memory deque (never evicted) ----------------

    fun emitInterceptShown(packageName: String) =
        emit("interceptShown", mapOf("pkg" to packageName))

    fun emitPermissionLost(kind: String) =
        emit("permissionLost", mapOf("kind" to kind), buffered = true)

    /**
     * Carries the full config (F-13, D-022) so Dart can synthesize the DB row
     * for a session that a schedule auto-started natively — Dart may have
     * never seen it. Plain restores of Dart-started sessions send it too;
     * Dart ignores the extras when it already has the row.
     */
    fun emitSessionRestored(config: NativeSessionConfig) =
        emit(
            "sessionRestored",
            mapOf(
                "sessionId" to config.id,
                "startedEpochMs" to config.startedEpochMs,
                "endEpochMs" to config.endEpochMs,
                "taskAnchor" to config.taskAnchor,
                "strictMode" to config.strictMode,
                "recoveryEnabled" to config.recoveryEnabled,
            ),
            buffered = true,
        )

    /**
     * Diagnostic for a `stopSession` id mismatch (D-013 P1-C): native was
     * holding [liveId] when Dart asked to stop [requestedId]. Buffered on the
     * restore-critical channel so it is never lost — Dart logs it and reconciles.
     * CONTRACTS §1 addendum (sanctioned by D-013).
     */
    fun emitStopMismatch(requestedId: String, liveId: String) =
        emit(
            "stopMismatch",
            mapOf("requestedId" to requestedId, "liveId" to liveId),
            buffered = true,
        )

    private fun emit(
        type: String,
        payload: Map<String, Any?>,
        buffered: Boolean = false,
    ) {
        val event = mapOf("type" to type) + payload
        val current = sink
        when {
            current != null -> current.success(event)
            buffered && pending.size < PENDING_LIMIT -> pending.addLast(event)
        }
    }
}
