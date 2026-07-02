package ch.hoffely.fokus.blocking

/**
 * Pure `stopSession` tiebreak logic (D-013 P1-C). No Android deps so it is
 * JVM-unit-testable (CONVENTIONS testing bar).
 *
 * The reviewer's finding: `stopSession` only acted when the requested id
 * matched the live native session, so a mismatch silently no-op'd — the DB
 * could say "terminal" while native kept blocking a *different* session.
 * D-013 ruling: **Dart decides liveness, always.** A stop request always stops
 * whatever native session is running (never a silent no-op) and, on a mismatch,
 * emits a diagnostic carrying both ids.
 */
object StopDecision {

    data class Decision(
        /** Always true (D-013): clear the cache + stop the service regardless. */
        val stop: Boolean,
        /** Emit the `stopMismatch` diagnostic — only when ids differ. */
        val emitMismatch: Boolean,
    )

    /**
     * [liveId] is the id native currently holds (null = none). [requestedId] is
     * the id Dart asked to stop.
     */
    fun decide(liveId: String?, requestedId: String): Decision {
        val mismatch = liveId != null && liveId != requestedId
        // Stop unconditionally: the foreground service is single-session, and
        // Dart's terminal decision wins. A no live session case still stops
        // (idempotent) so a redundant stop is never an error.
        return Decision(stop = true, emitMismatch = mismatch)
    }
}
