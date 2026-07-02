package ch.hoffely.fokus.blocking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * D-013 P1-A: the attempt journal must never drop a distraction attempt.
 * These tests exercise the pure [JournalCore] (persistence/replay/ack) — the
 * SharedPreferences glue is a thin pass-through around it.
 */
class JournalCoreTest {

    // Simulates the two persisted prefs values the Android glue holds.
    private class FakePrefs {
        var entries: String? = null
        var nextSeq: Long = 0L

        fun appendDistraction(pkg: String, ts: Long): Long {
            val r = JournalCore.appendDistraction(entries, nextSeq, pkg, ts)
            entries = r.entriesJson
            nextSeq = r.assignedSeq + 1
            return r.assignedSeq
        }

        fun appendRecovery(ts: Long): Long {
            val r = JournalCore.appendRecovery(entries, nextSeq, ts)
            entries = r.entriesJson
            nextSeq = r.assignedSeq + 1
            return r.assignedSeq
        }

        fun entries() = JournalCore.entries(entries)

        fun ack(upToSeq: Long) {
            entries = JournalCore.ack(entries, upToSeq)
        }
    }

    // --- append + replay ------------------------------------------------

    @Test
    fun `appended attempts replay in seq order with their true ts`() {
        val p = FakePrefs()
        assertEquals(0L, p.appendDistraction("com.instagram", 1000L))
        assertEquals(1L, p.appendDistraction("com.tiktok", 2000L))

        val entries = p.entries()
        assertEquals(2, entries.size)
        assertEquals(JournalCore.TYPE_DISTRACTION, entries[0]["type"])
        assertEquals("com.instagram", entries[0]["pkg"])
        assertEquals(1000L, entries[0]["ts"])
        assertEquals(0L, entries[0]["seq"])
        assertEquals("com.tiktok", entries[1]["pkg"])
        assertEquals(1L, entries[1]["seq"])
    }

    @Test
    fun `recovery entries carry type and ts but no pkg`() {
        val p = FakePrefs()
        p.appendRecovery(5000L)
        val e = p.entries().single()
        assertEquals(JournalCore.TYPE_RECOVERY, e["type"])
        assertEquals(5000L, e["ts"])
        assertNull(e["pkg"])
    }

    // --- unbounded within a session (the P1-A regression) ---------------

    @Test
    fun `far more than the old 16-slot limit are all retained`() {
        val p = FakePrefs()
        repeat(50) { i -> p.appendDistraction("com.app$i", i.toLong()) }
        assertEquals(50, p.entries().size) // nothing dropped
    }

    // --- ack drops a contiguous prefix ----------------------------------

    @Test
    fun `ack drops entries up to and including the acked seq`() {
        val p = FakePrefs()
        p.appendDistraction("a", 1L) // seq 0
        p.appendDistraction("b", 2L) // seq 1
        p.appendDistraction("c", 3L) // seq 2

        p.ack(1L)

        val remaining = p.entries()
        assertEquals(1, remaining.size)
        assertEquals("c", remaining.single()["pkg"])
        assertEquals(2L, remaining.single()["seq"])
    }

    @Test
    fun `entries journalled during replay (higher seq) survive an earlier ack`() {
        val p = FakePrefs()
        p.appendDistraction("a", 1L) // seq 0
        p.appendDistraction("b", 2L) // seq 1
        // Dart is mid-replay of seq 0..1 when a new attempt arrives:
        p.appendDistraction("c", 3L) // seq 2
        // ...then Dart acks only what it had drained (0..1):
        p.ack(1L)

        assertEquals(listOf("c"), p.entries().map { it["pkg"] })
    }

    // --- at-least-once: crash after replay, before ack ------------------

    @Test
    fun `replay-after-crash re-delivers unacked entries (at-least-once)`() {
        val p = FakePrefs()
        p.appendDistraction("a", 1L)
        p.appendDistraction("b", 2L)

        // Dart attaches, replays both, but the process dies before ack.
        val firstReplay = p.entries().map { it["pkg"] }
        assertEquals(listOf("a", "b"), firstReplay)

        // Next attach: the same entries are still there → replayed again.
        val secondReplay = p.entries().map { it["pkg"] }
        assertEquals(firstReplay, secondReplay) // nothing lost
    }

    // --- monotonic seq across a session boundary ------------------------

    @Test
    fun `seq stays monotonic across a clear so a stale ack cannot match`() {
        val p = FakePrefs()
        p.appendDistraction("old", 1L) // seq 0
        // Session ends → glue clears entries but NOT the seq counter.
        p.entries = null
        // New session's first attempt gets seq 1, never reusing 0.
        assertEquals(1L, p.appendDistraction("new", 9L))
        // A stale in-flight ack(0) from the previous session is a no-op now.
        p.ack(0L)
        assertEquals(listOf("new"), p.entries().map { it["pkg"] })
    }

    // --- robustness -----------------------------------------------------

    @Test
    fun `null or corrupt json reads as empty, appends cleanly`() {
        assertTrue(JournalCore.entries(null).isEmpty())
        assertTrue(JournalCore.entries("not json").isEmpty())
        val r = JournalCore.appendDistraction("garbage", 0L, "a", 1L)
        assertEquals(1, JournalCore.entries(r.entriesJson).size)
    }
}
