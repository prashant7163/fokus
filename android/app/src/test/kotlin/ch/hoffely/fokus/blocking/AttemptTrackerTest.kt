package ch.hoffely.fokus.blocking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AttemptTrackerTest {

    private val now = 1_750_000_000_000L
    private val fiveMin = AttemptTracker.WINDOW_MS

    @Test
    fun `counts attempts inside the window`() {
        val tracker = AttemptTracker()
        assertEquals(1, tracker.record(now))
        assertEquals(2, tracker.record(now + 1_000))
        assertEquals(3, tracker.record(now + 2_000))
    }

    @Test
    fun `attempts outside the window are pruned`() {
        val tracker = AttemptTracker()
        tracker.record(now)
        tracker.record(now + 1_000)
        // Third attempt lands after the first two have aged out.
        assertEquals(1, tracker.record(now + 1_000 + fiveMin))
    }

    @Test
    fun `attempt exactly window-age is out (exclusive boundary)`() {
        val tracker = AttemptTracker()
        tracker.record(now)
        assertEquals(1, tracker.countWithin(now + fiveMin - 1))
        assertEquals(0, tracker.countWithin(now + fiveMin))
    }

    @Test
    fun `hint threshold - 3 attempts in 5 minutes (spec 3-2)`() {
        assertFalse(AttemptTracker.shouldShowHint(2))
        assertTrue(AttemptTracker.shouldShowHint(3))
        assertTrue(AttemptTracker.shouldShowHint(4))
    }

    @Test
    fun `hint fires on realistic repeated-temptation sequence`() {
        val tracker = AttemptTracker()
        var count = tracker.record(now) // open Instagram
        count = tracker.record(now + 60_000) // again a minute later
        assertFalse(AttemptTracker.shouldShowHint(count))
        count = tracker.record(now + 3 * 60_000) // third try
        assertTrue(AttemptTracker.shouldShowHint(count))
    }

    @Test
    fun `ring buffer is bounded`() {
        val tracker = AttemptTracker(windowMs = Long.MAX_VALUE / 2, maxEntries = 5)
        repeat(100) { tracker.record(now + it) }
        assertEquals(5, tracker.countWithin(now + 100))
    }
}
