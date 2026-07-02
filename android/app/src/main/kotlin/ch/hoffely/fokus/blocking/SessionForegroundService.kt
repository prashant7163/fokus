package ch.hoffely.fokus.blocking

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import ch.hoffely.fokus.R

/**
 * Session resilience (ARCHITECTURE resilience requirements, F-04).
 *
 * Runs for the lifetime of an active session with a persistent countdown
 * notification. START_STICKY + wall-clock anchoring means a process kill
 * re-delivers a null intent and the service re-hydrates from
 * [BlockedSetCache] (SharedPreferences-backed); [BootReceiver] does the
 * same after reboot.
 *
 * Mechanism only (CONTRACTS §2): this service never decides session
 * transitions. On restore it emits `sessionRestored`; on natural expiry it
 * simply stops — Dart owns the `completed` transition. If the accessibility
 * permission disappears mid-session it emits `permissionLost` and keeps
 * running until Dart rules.
 */
class SessionForegroundService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private val ticker = Runnable { onTick() }
    private var permissionLossReported = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        BlockedSetCache.ensureLoaded(this)

        // Must enter the foreground before anything else — the 5 s
        // startForegroundService() contract applies even when we are about
        // to stop (e.g. stale sticky restart with no live session).
        val session = BlockedSetCache.session
        val plan = SessionServicePlan.planFor(session, System.currentTimeMillis())
        startInForeground(session, plan)

        if (intent?.action == ACTION_STOP) {
            stopAndRemove()
            return START_NOT_STICKY
        }

        return when (plan) {
            is SessionServicePlan.Plan.Run -> {
                // Null intent = sticky restart after process death.
                val restored = intent == null ||
                    intent.getBooleanExtra(EXTRA_RESTORED, false)
                if (restored && session != null) {
                    FokusEventBus.emitSessionRestored(session)
                }
                scheduleTick(plan.nextTickDelayMs)
                START_STICKY
            }

            else -> {
                stopForPlan(plan)
                START_NOT_STICKY
            }
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        super.onDestroy()
    }

    private fun onTick() {
        val session = BlockedSetCache.session
        when (val plan = SessionServicePlan.planFor(session, System.currentTimeMillis())) {
            is SessionServicePlan.Plan.Run -> {
                notificationManager().notify(
                    NOTIFICATION_ID,
                    buildNotification(session, plan.remainingMinutes),
                )
                watchAccessibilityPermission()
                scheduleTick(plan.nextTickDelayMs)
            }

            // Timer end (or session cleared): stop. Dart decides the
            // resulting transition (CONTRACTS §2).
            else -> stopForPlan(plan)
        }
    }

    /**
     * Stop path for a non-Run plan. On natural expiry (D-013 P1-B) the stale
     * session config is cleared from [BlockedSetCache] so native and Dart agree
     * no session is live, even if the process is killed before Dart reconciles
     * (BootReceiver would otherwise read an expired row). `NoSession` has
     * nothing to clear.
     */
    private fun stopForPlan(plan: SessionServicePlan.Plan) {
        if (SessionServicePlan.clearsCacheOnStop(plan)) {
            BlockedSetCache.clearSession(this)
        }
        stopAndRemove()
    }

    private fun scheduleTick(delayMs: Long) {
        handler.removeCallbacks(ticker)
        handler.postDelayed(ticker, delayMs)
    }

    /** No silent failure (ARCHITECTURE): report a revoked permission once. */
    private fun watchAccessibilityPermission() {
        if (permissionLossReported) return
        if (!FokusAccessibilityService.isEnabled(this)) {
            permissionLossReported = true
            FokusEventBus.emitPermissionLost("accessibility")
        }
    }

    private fun startInForeground(
        session: NativeSessionConfig?,
        plan: SessionServicePlan.Plan,
    ) {
        ensureChannel()
        val minutes = (plan as? SessionServicePlan.Plan.Run)?.remainingMinutes ?: 0
        val notification = buildNotification(session, minutes)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopAndRemove() {
        handler.removeCallbacks(ticker)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(
        session: NativeSessionConfig?,
        remainingMinutes: Int,
    ): Notification {
        val title = session?.taskAnchor?.takeIf { it.isNotBlank() }
            ?: getString(R.string.session_notification_title_fallback)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_session)
            .setContentTitle(title)
            .setContentText(
                getString(R.string.session_notification_text, remainingMinutes),
            )
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(launchAppIntent())
            .build()
    }

    private fun launchAppIntent(): PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
            ?: return null
        return PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.session_notification_channel_name),
            NotificationManager.IMPORTANCE_LOW, // silent, no heads-up
        ).apply {
            description = getString(R.string.session_notification_channel_description)
            setShowBadge(false)
        }
        notificationManager().createNotificationChannel(channel)
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    companion object {
        private const val CHANNEL_ID = "fokus_session"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_STOP = "ch.hoffely.fokus.action.STOP_SESSION"
        private const val EXTRA_RESTORED = "restored"

        /** Start (or restore, from [BootReceiver]) the session service. */
        fun start(context: Context, restored: Boolean) {
            val intent = Intent(context, SessionForegroundService::class.java)
                .putExtra(EXTRA_RESTORED, restored)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Stop the service and remove the notification (stopSession). */
        fun stop(context: Context) {
            // Routed through onStartCommand so the foreground contract is
            // honoured even if a start is still pending.
            val intent = Intent(context, SessionForegroundService::class.java)
                .setAction(ACTION_STOP)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
