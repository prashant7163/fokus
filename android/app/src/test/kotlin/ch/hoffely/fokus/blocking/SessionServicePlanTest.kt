package ch.hoffely.fokus.blocking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SessionServicePlanTest {

    private val now = 1_750_000_000_000L

    private fun session(endInMs: Long) = NativeSessionConfig(
        id = "s1",
        endEpochMs = now + endInMs,
        taskAnchor = "Write report",
        strictMode = false,
    )

    // --- planFor: restore/run decision --------------------------------

    @Test
    fun `no cached session - NoSession`() {
        assertEquals(
            SessionServicePlan.Plan.NoSession,
            SessionServicePlan.planFor(null, now),
        )
    }

    @Test
    fun `session ended in the past - Expired`() {
        assertEquals(
            SessionServicePlan.Plan.Expired,
            SessionServicePlan.planFor(session(-1L), now),
        )
    }

    @Test
    fun `session ending exactly now - Expired (wall-clock anchored)`() {
        assertEquals(
            SessionServicePlan.Plan.Expired,
            SessionServicePlan.planFor(session(0L), now),
        )
    }

    @Test
    fun `live session - Run with remaining minutes and tick delay`() {
        val plan = SessionServicePlan.planFor(session(30 * 60_000L), now)
        assertTrue(plan is SessionServicePlan.Plan.Run)
        plan as SessionServicePlan.Plan.Run
        assertEquals(30, plan.remainingMinutes)
        assertEquals(60_000L, plan.nextTickDelayMs)
    }

    @Test
    fun `one millisecond left - still Run, shows 1 min`() {
        val plan = SessionServicePlan.planFor(session(1L), now)
        assertTrue(plan is SessionServicePlan.Plan.Run)
        assertEquals(1, (plan as SessionServicePlan.Plan.Run).remainingMinutes)
    }

    // --- remainingMinutes: ceiling, never 0 while live -----------------

    @Test
    fun `remaining minutes rounds up`() {
        assertEquals(1, SessionServicePlan.remainingMinutes(1L))
        assertEquals(1, SessionServicePlan.remainingMinutes(59_999L))
        assertEquals(1, SessionServicePlan.remainingMinutes(60_000L))
        assertEquals(2, SessionServicePlan.remainingMinutes(60_001L))
        assertEquals(120, SessionServicePlan.remainingMinutes(120 * 60_000L))
    }

    // --- nextTickDelayMs: aligned to the session's minute boundary -----

    @Test
    fun `tick fires when displayed minute changes`() {
        // 90 s left → display flips from 2 to 1 min in 30 s.
        assertEquals(30_000L, SessionServicePlan.nextTickDelayMs(90_000L))
        // 61 s left → flips in 1 s.
        assertEquals(1_000L, SessionServicePlan.nextTickDelayMs(61_000L))
    }

    @Test
    fun `exact minute boundary - next tick a full minute out`() {
        assertEquals(60_000L, SessionServicePlan.nextTickDelayMs(60_000L))
        assertEquals(60_000L, SessionServicePlan.nextTickDelayMs(30 * 60_000L))
    }

    @Test
    fun `final stretch - tick lands exactly at session end`() {
        // 59 s left (displaying 1 min): next tick after 59 s = at expiry,
        // where planFor returns Expired and the service stops.
        assertEquals(59_000L, SessionServicePlan.nextTickDelayMs(59_000L))
        val atEnd = SessionServicePlan.planFor(session(59_000L), now + 59_000L)
        assertEquals(SessionServicePlan.Plan.Expired, atEnd)
    }
}
