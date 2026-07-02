package ch.hoffely.fokus.blocking

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InterceptDeciderTest {

    private val now = 1_750_000_000_000L
    private val session = NativeSessionConfig(
        id = "s1",
        endEpochMs = now + 30 * 60_000L,
        taskAnchor = "Write report",
        strictMode = false,
    )
    private val blocked = setOf("com.instagram.android", "com.tiktok")
    private val neverBlockable =
        setOf("ch.hoffely.fokus", "com.android.systemui", "android")

    private fun decide(
        pkg: String? = "com.instagram.android",
        nowMs: Long = now,
        session: NativeSessionConfig? = this.session,
        blockedSet: Set<String> = blocked,
        never: Set<String> = neverBlockable,
        lastPkg: String? = null,
        lastAtMs: Long = 0L,
    ) = InterceptDecider.shouldIntercept(
        packageName = pkg,
        nowMs = nowMs,
        session = session,
        blockedSet = blockedSet,
        neverBlockable = never,
        lastInterceptPackage = lastPkg,
        lastInterceptAtMs = lastAtMs,
    )

    @Test
    fun `intercepts blocked app during active session`() {
        assertTrue(decide())
    }

    @Test
    fun `no session - no intercept`() {
        assertFalse(decide(session = null))
    }

    @Test
    fun `expired session - no intercept (wall-clock anchored)`() {
        assertFalse(decide(nowMs = session.endEpochMs))
        assertFalse(decide(nowMs = session.endEpochMs + 1))
        assertTrue(decide(nowMs = session.endEpochMs - 1))
    }

    @Test
    fun `unblocked app - no intercept`() {
        assertFalse(decide(pkg = "com.spotify.music"))
    }

    @Test
    fun `never-blockable wins even if present in blocked set`() {
        assertFalse(
            decide(
                pkg = "com.android.systemui",
                blockedSet = blocked + "com.android.systemui",
            ),
        )
    }

    @Test
    fun `null or empty package - no intercept`() {
        assertFalse(decide(pkg = null))
        assertFalse(decide(pkg = ""))
    }

    @Test
    fun `same package within debounce window is suppressed`() {
        assertFalse(
            decide(
                lastPkg = "com.instagram.android",
                lastAtMs = now - (InterceptDecider.DEBOUNCE_MS - 1),
            ),
        )
    }

    @Test
    fun `same package after debounce window intercepts again`() {
        assertTrue(
            decide(
                lastPkg = "com.instagram.android",
                lastAtMs = now - InterceptDecider.DEBOUNCE_MS,
            ),
        )
    }

    @Test
    fun `different package inside debounce window still intercepts`() {
        assertTrue(
            decide(
                pkg = "com.tiktok",
                lastPkg = "com.instagram.android",
                lastAtMs = now - 100,
            ),
        )
    }
}
