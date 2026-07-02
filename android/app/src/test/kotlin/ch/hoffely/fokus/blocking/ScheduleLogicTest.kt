package ch.hoffely.fokus.blocking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId

class ScheduleLogicTest {

    private val zone: ZoneId = ZoneId.of("Europe/Zurich")

    private fun schedule(
        days: Set<Int>,
        time: String,
    ) = NativeSchedule(
        id = 1,
        presetName = "Deep work",
        packages = listOf("com.instagram.android"),
        durationMin = 60,
        strictMode = false,
        recoveryEnabled = true,
        daysOfWeek = days,
        startLocalTime = time,
    )

    private fun ms(dateTime: LocalDateTime): Long =
        dateTime.atZone(zone).toInstant().toEpochMilli()

    // 2026-07-02 is a Thursday (ISO day 4).

    @Test
    fun `same day when the time is still ahead`() {
        val now = ms(LocalDateTime.of(2026, 7, 2, 9, 0))
        val next = ScheduleLogic.nextOccurrenceMs(
            schedule(setOf(4), "10:30"),
            now,
            zone,
        )
        assertEquals(ms(LocalDateTime.of(2026, 7, 2, 10, 30)), next)
    }

    @Test
    fun `same weekday next week when today's time already passed`() {
        val now = ms(LocalDateTime.of(2026, 7, 2, 10, 30))
        val next = ScheduleLogic.nextOccurrenceMs(
            schedule(setOf(4), "10:30"),
            now,
            zone,
        )
        // Strictly after now → next Thursday.
        assertEquals(ms(LocalDateTime.of(2026, 7, 9, 10, 30)), next)
    }

    @Test
    fun `picks the earliest of several weekdays`() {
        val now = ms(LocalDateTime.of(2026, 7, 2, 12, 0)) // Thu noon
        val next = ScheduleLogic.nextOccurrenceMs(
            schedule(setOf(1, 6), "08:00"), // Mon + Sat
            now,
            zone,
        )
        assertEquals(ms(LocalDateTime.of(2026, 7, 4, 8, 0)), next) // Saturday
    }

    @Test
    fun `weekend-only schedule from a weekday`() {
        val now = ms(LocalDateTime.of(2026, 6, 29, 7, 0)) // Monday
        val next = ScheduleLogic.nextOccurrenceMs(
            schedule(setOf(7), "09:15"),
            now,
            zone,
        )
        assertEquals(ms(LocalDateTime.of(2026, 7, 5, 9, 15)), next) // Sunday
    }

    @Test
    fun `no weekdays means no occurrence`() {
        val now = ms(LocalDateTime.of(2026, 7, 2, 9, 0))
        assertNull(ScheduleLogic.nextOccurrenceMs(schedule(emptySet(), "10:00"), now, zone))
    }

    @Test
    fun `midnight boundary - 00_00 today already passed lands next week`() {
        val now = ms(LocalDateTime.of(2026, 7, 2, 0, 0, 1))
        val next = ScheduleLogic.nextOccurrenceMs(
            schedule(setOf(4), "00:00"),
            now,
            zone,
        )
        assertEquals(ms(LocalDateTime.of(2026, 7, 9, 0, 0)), next)
    }

    // --- shouldStart (skip-once + never clobber a live session) -----------

    @Test
    fun `starts normally`() {
        assertTrue(ScheduleLogic.shouldStart(null, 1000L, null))
    }

    @Test
    fun `skip marker for this occurrence vetoes once`() {
        assertFalse(ScheduleLogic.shouldStart(1000L, 1000L, null))
    }

    @Test
    fun `stale skip marker from an older occurrence does not veto`() {
        assertTrue(ScheduleLogic.shouldStart(500L, 1000L, null))
    }

    @Test
    fun `a live session always vetoes - never clobber`() {
        assertFalse(ScheduleLogic.shouldStart(null, 1000L, "live-session-id"))
    }

    // --- schedule JSON round-trip (prefs persistence) ----------------------

    @Test
    fun `schedule survives a JSON round trip`() {
        val original = schedule(setOf(1, 3, 5), "07:45").copy(strictMode = true)
        val restored = NativeSchedule.fromJson(original.toJson())
        assertEquals(original, restored)
    }
}
