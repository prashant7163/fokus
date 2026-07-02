package ch.hoffely.fokus.blocking

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** D-013 P1-C: stopSession is never a silent no-op; a mismatch is diagnosed. */
class StopDecisionTest {

    @Test
    fun `matching id - stop, no diagnostic`() {
        val d = StopDecision.decide(liveId = "s1", requestedId = "s1")
        assertTrue(d.stop)
        assertFalse(d.emitMismatch)
    }

    @Test
    fun `mismatched id - still stops AND emits diagnostic (never a no-op)`() {
        val d = StopDecision.decide(liveId = "sB", requestedId = "sA")
        assertTrue(d.stop) // the old silent-no-op bug is gone
        assertTrue(d.emitMismatch)
    }

    @Test
    fun `no live session - stop is idempotent, no diagnostic`() {
        val d = StopDecision.decide(liveId = null, requestedId = "sA")
        assertTrue(d.stop)
        assertFalse(d.emitMismatch)
    }
}
