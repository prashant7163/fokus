package ch.hoffely.fokus.blocking

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import ch.hoffely.fokus.MainActivity
import ch.hoffely.fokus.R

/**
 * Blocked-app intercept (ARCHITECTURE step 2; design/SCREENS.md §4 — must
 * match 1:1). Native so it renders < 200 ms from cold, no Flutter engine.
 * UI is built in code: no inflation, no androidx dependency, nothing on the
 * critical path but this file.
 *
 * Colors/typography are the DESIGN_SYSTEM.md v2 *light* literals (D-009;
 * the Flutter app gained a theme toggle with F-12 — this native screen stays
 * light until a native dark variant is worth the maintenance). Plus Jakarta
 * Sans is bundled via res/font (D-020), with a system-sans fallback below
 * API 26.
 *
 * CTA wiring:
 * - "Return to focus"  → home screen (leaves the blocked app behind).
 * - "I'm stuck"        → `recoveryRequested` event (CONTRACTS §1, buffered)
 *                        + deep link `fokus://app/recovery` (Flutter's own
 *                        deep-linking; cold + warm engine both covered).
 *                        With the proactive hint active, Breathe is
 *                        pre-selected via `?module=breathe`.
 * - "Emergency exit"   → deep link `fokus://app/exit` → Dart exit-reason flow
 *                        (F-08). Navigation only — Dart decides transitions.
 *
 * go_router must register `/recovery` and `/exit` for these URIs — seam
 * documented for F-06/F-07/F-08.
 */
class InterceptActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private val ticker = Runnable { updateCountdown() }
    private var timeView: TextView? = null
    private var hintActive = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BlockedSetCache.ensureLoaded(this)
        render()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        render()
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        super.onDestroy()
    }

    // ---------------------------------------------------------------- UI

    private fun render() {
        val session = BlockedSetCache.session
        if (SessionServicePlan.planFor(session, now()) !is SessionServicePlan.Plan.Run) {
            finish()
            return
        }
        session!!

        val pkg = intent.getStringExtra(EXTRA_PKG) ?: ""
        val attempts = intent.getIntExtra(EXTRA_ATTEMPTS, 1)
        hintActive = AttemptTracker.shouldShowHint(attempts)
        val appLabel = appLabel(pkg)

        // TalkBack announces the window title first (SCREENS §4 a11y).
        title = getString(R.string.intercept_headline, appLabel)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(SURFACE)
            setPadding(dp(24), dp(48), dp(24), dp(24))
        }

        // 1. FOKUS ring mark — "this is your app, not a system error".
        root.addView(
            ImageView(this).apply {
                setImageResource(R.drawable.ic_fokus_ring)
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            },
            lp(dp(28), dp(28)),
        )

        root.addView(spacer(weight = 1f))

        // 2. App identity — real icon + warm headline.
        appIcon(pkg)?.let { icon ->
            root.addView(
                ImageView(this).apply {
                    setImageDrawable(icon)
                    contentDescription =
                        getString(R.string.intercept_icon_description, appLabel)
                },
                lp(dp(64), dp(64)),
            )
        }
        root.addView(
            text(
                getString(R.string.intercept_headline, appLabel),
                sizeSp = 24f,
                color = ON_SURFACE,
                bold = true,
            ).apply {
                gravity = Gravity.CENTER
                setPadding(0, dp(16), 0, 0)
            },
        )

        // 3. Time remaining (ticks with the session's minute boundary).
        timeView = text("", sizeSp = 16f, color = ON_SURFACE_VARIANT).apply {
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, 0)
        }
        root.addView(timeView)
        updateCountdown()

        // 4. Task anchor card (omitted cleanly when unset).
        session.taskAnchor?.takeIf { it.isNotBlank() }?.let { anchor ->
            root.addView(
                text(
                    getString(R.string.intercept_anchor, anchor),
                    sizeSp = 16f,
                    color = ON_SURFACE,
                ).apply {
                    background = card(SURFACE_CONTAINER_LOW, OUTLINE_VARIANT)
                    setPadding(dp(16), dp(16), dp(16), dp(16))
                    gravity = Gravity.CENTER
                },
                lp(MATCH, WRAP, topDp = 24),
            )
        }

        root.addView(spacer(weight = 1f))

        // 7. Proactive recovery hint (≥ 3 attempts in 5 min; spec §3.2).
        if (hintActive) {
            root.addView(
                text(
                    getString(R.string.intercept_hint_repeated),
                    sizeSp = 14f,
                    color = ON_SECONDARY_CONTAINER,
                ).apply {
                    background = card(SECONDARY_CONTAINER, null)
                    setPadding(dp(16), dp(12), dp(16), dp(12))
                    gravity = Gravity.CENTER
                },
                lp(MATCH, WRAP, bottomDp = 12),
            )
        }

        // 5. CTA1 — Return to focus (focus-gradient hero).
        root.addView(
            button(
                getString(R.string.intercept_cta_return),
                textColor = Color.WHITE,
                background = focusGradient(),
            ) { returnToFocus() },
            lp(MATCH, dp(56)),
        )

        // 6. CTA2 — I'm stuck (tonal → recovery).
        root.addView(
            button(
                getString(R.string.intercept_cta_stuck),
                textColor = ON_SECONDARY_CONTAINER,
                background = fill(SECONDARY_CONTAINER),
            ) { openRecovery() },
            lp(MATCH, dp(56), topDp = 12),
        )

        // 8. CTA3 — Emergency exit (de-emphasized, never hidden).
        root.addView(
            button(
                getString(R.string.intercept_cta_emergency),
                textColor = ON_SURFACE_VARIANT,
                background = null,
            ) { openExitFlow() },
            lp(MATCH, dp(56), topDp = 8),
        )

        setContentView(
            ScrollView(this).apply {
                isFillViewport = true
                addView(
                    root,
                    FrameLayout.LayoutParams(MATCH, FrameLayout.LayoutParams.MATCH_PARENT),
                )
            },
        )

        if (pkg.isNotEmpty()) FokusEventBus.emitInterceptShown(pkg)
    }

    private fun updateCountdown() {
        val plan = SessionServicePlan.planFor(BlockedSetCache.session, now())
        if (plan !is SessionServicePlan.Plan.Run) {
            finish() // session over mid-intercept — nothing to hold back
            return
        }
        timeView?.text = resources.getQuantityString(
            R.plurals.intercept_time_remaining,
            plan.remainingMinutes,
            plan.remainingMinutes,
        )
        handler.removeCallbacks(ticker)
        handler.postDelayed(ticker, plan.nextTickDelayMs)
    }

    // ------------------------------------------------------------- CTAs

    private fun returnToFocus() {
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        finish()
    }

    private fun openRecovery() {
        FokusEventBus.emitRecoveryRequested(this, System.currentTimeMillis())
        val uri = if (hintActive) "$URI_RECOVERY?module=breathe" else URI_RECOVERY
        deepLink(uri)
    }

    private fun openExitFlow() = deepLink(URI_EXIT)

    private fun deepLink(uri: String) {
        startActivity(
            Intent(this, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW)
                .setData(Uri.parse(uri))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        finish()
    }

    // ---------------------------------------------------------- helpers

    private fun appLabel(pkg: String): String = try {
        packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(pkg, 0),
        ).toString()
    } catch (e: Exception) {
        pkg.substringAfterLast('.')
            .replaceFirstChar { it.uppercase() }
    }

    private fun appIcon(pkg: String): Drawable? = try {
        packageManager.getApplicationIcon(pkg)
    } catch (e: Exception) {
        null
    }

    private fun text(
        value: CharSequence,
        sizeSp: Float,
        color: Int,
        bold: Boolean = false,
    ): TextView = TextView(this).apply {
        text = value
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(color)
        // Plus Jakarta Sans (bundled per D-020); resources.getFont needs
        // API 26 — older devices keep system sans, visually close enough.
        typeface = if (android.os.Build.VERSION.SDK_INT >= 26) {
            resources.getFont(
                if (bold) {
                    ch.hoffely.fokus.R.font.plus_jakarta_sans_bold
                } else {
                    ch.hoffely.fokus.R.font.plus_jakarta_sans_regular
                },
            )
        } else {
            Typeface.create(
                Typeface.SANS_SERIF,
                if (bold) Typeface.BOLD else Typeface.NORMAL,
            )
        }
    }

    private fun button(
        label: String,
        textColor: Int,
        background: Drawable?,
        onClick: () -> Unit,
    ): TextView = text(label, sizeSp = 16f, color = textColor, bold = true).apply {
        gravity = Gravity.CENTER
        this.background = background
        isClickable = true
        isFocusable = true
        setOnClickListener { onClick() }
    }

    /** radius.sm (12) per DESIGN_SYSTEM buttons. */
    private fun fill(color: Int): GradientDrawable = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(12).toFloat()
    }

    /** Ember focus-gradient, 135° (DESIGN_SYSTEM non-scheme extras). */
    private fun focusGradient(): GradientDrawable = GradientDrawable(
        GradientDrawable.Orientation.TL_BR,
        intArrayOf(GRADIENT_START, GRADIENT_END),
    ).apply { cornerRadius = dp(12).toFloat() }

    /** radius.md (16) card with optional hairline border. */
    private fun card(color: Int, borderColor: Int?): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(16).toFloat()
            borderColor?.let { setStroke(dp(1), it) }
        }

    private fun spacer(weight: Float): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(0, 0, weight)
    }

    private fun lp(
        width: Int,
        height: Int,
        topDp: Int = 0,
        bottomDp: Int = 0,
    ): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(width, height).apply {
            topMargin = dp(topDp)
            bottomMargin = dp(bottomDp)
        }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun now(): Long = System.currentTimeMillis()

    companion object {
        private const val EXTRA_PKG = "pkg"
        private const val EXTRA_ATTEMPTS = "attemptsInWindow"
        // The route must live in the URI *path*: Flutter's Android embedding
        // maps a deep link to path+query only (the host is dropped), so
        // `fokus://recovery` would boot the engine at "/" (found in the M2
        // emulator pass). The `app` host is arbitrary and not matched.
        private const val URI_RECOVERY = "fokus://app/recovery"
        private const val URI_EXIT = "fokus://app/exit"

        private const val MATCH = LinearLayout.LayoutParams.MATCH_PARENT
        private const val WRAP = LinearLayout.LayoutParams.WRAP_CONTENT

        // DESIGN_SYSTEM.md §1 light-scheme literals (v2, D-009).
        private const val SURFACE = 0xFFFBF9F6.toInt()
        private const val ON_SURFACE = 0xFF22201D.toInt()
        private const val ON_SURFACE_VARIANT = 0xFF55524C.toInt()
        private const val SURFACE_CONTAINER_LOW = 0xFFFAF7F2.toInt()
        private const val OUTLINE_VARIANT = 0xFFD6CFC3.toInt()
        private const val SECONDARY_CONTAINER = 0xFFDDE7D0.toInt()
        private const val ON_SECONDARY_CONTAINER = 0xFF26301E.toInt()
        private const val GRADIENT_START = 0xFFFF7A30.toInt()
        private const val GRADIENT_END = 0xFFE8611F.toInt()

        /** Launched by [FokusAccessibilityService] on a positive intercept. */
        fun launch(context: Context, packageName: String, attemptsInWindow: Int) {
            context.startActivity(
                Intent(context, InterceptActivity::class.java)
                    .putExtra(EXTRA_PKG, packageName)
                    .putExtra(EXTRA_ATTEMPTS, attemptsInWindow)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }
}
