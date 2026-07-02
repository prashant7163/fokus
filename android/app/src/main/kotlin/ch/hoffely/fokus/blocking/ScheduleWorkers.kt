package ch.hoffely.fokus.blocking

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import ch.hoffely.fokus.R
import java.time.ZoneId
import java.util.UUID
import java.util.concurrent.TimeUnit

/**
 * WorkManager arming for schedules (F-13, fokus-specs §3.7): per enabled
 * schedule, a reminder at T−5 min (with a "Skip" action) and the auto-start
 * at T. Each worker re-arms the next occurrence after firing, and WorkManager
 * persists enqueued work across reboots.
 *
 * Mechanism only: the schedule list itself is policy, synced from Dart.
 */
object ScheduleArmer {

    private const val START_PREFIX = "fokus_sched_start_"
    private const val REMIND_PREFIX = "fokus_sched_remind_"

    const val KEY_SCHEDULE_ID = "scheduleId"
    const val KEY_OCCURRENCE_MS = "occurrenceMs"

    /** Replaces all armed work with the given schedule set. */
    fun rearmAll(context: Context, schedules: List<NativeSchedule>) {
        val wm = WorkManager.getInstance(context)
        // Cancel work for schedules that no longer exist, then (re)arm.
        for (old in ScheduleStore.load(context)) {
            if (schedules.none { it.id == old.id }) {
                wm.cancelUniqueWork(START_PREFIX + old.id)
                wm.cancelUniqueWork(REMIND_PREFIX + old.id)
            }
        }
        ScheduleStore.save(context, schedules)
        schedules.forEach { armNext(context, it) }
    }

    /** Arms the next occurrence of [schedule] (start + reminder). */
    fun armNext(context: Context, schedule: NativeSchedule) {
        val now = System.currentTimeMillis()
        val occurrence = ScheduleLogic.nextOccurrenceMs(
            schedule,
            now,
            ZoneId.systemDefault(),
        ) ?: return
        val wm = WorkManager.getInstance(context)
        val data = Data.Builder()
            .putInt(KEY_SCHEDULE_ID, schedule.id)
            .putLong(KEY_OCCURRENCE_MS, occurrence)
            .build()

        wm.enqueueUniqueWork(
            START_PREFIX + schedule.id,
            ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<ScheduleStartWorker>()
                .setInitialDelay(occurrence - now, TimeUnit.MILLISECONDS)
                .setInputData(data)
                .build(),
        )

        val remindDelay =
            occurrence - now - TimeUnit.MINUTES.toMillis(ScheduleLogic.REMINDER_LEAD_MIN)
        if (remindDelay > 0) {
            wm.enqueueUniqueWork(
                REMIND_PREFIX + schedule.id,
                ExistingWorkPolicy.REPLACE,
                OneTimeWorkRequestBuilder<ScheduleReminderWorker>()
                    .setInitialDelay(remindDelay, TimeUnit.MILLISECONDS)
                    .setInputData(data)
                    .build(),
            )
        }
    }
}

/** T−5 min: "starting soon" notification with a one-shot Skip action. */
class ScheduleReminderWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        val scheduleId = inputData.getInt(ScheduleArmer.KEY_SCHEDULE_ID, -1)
        val occurrence = inputData.getLong(ScheduleArmer.KEY_OCCURRENCE_MS, 0L)
        val schedule =
            ScheduleStore.byId(applicationContext, scheduleId) ?: return Result.success()

        val ctx = applicationContext
        ensureChannel(ctx)
        val skipIntent = Intent(ctx, ScheduleSkipReceiver::class.java)
            .putExtra(ScheduleArmer.KEY_SCHEDULE_ID, scheduleId)
            .putExtra(ScheduleArmer.KEY_OCCURRENCE_MS, occurrence)
        val skipPending = PendingIntent.getBroadcast(
            ctx,
            scheduleId,
            skipIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = Notification.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_session)
            .setContentTitle(
                ctx.getString(R.string.schedule_reminder_title, schedule.presetName),
            )
            .setContentText(ctx.getString(R.string.schedule_reminder_body))
            .addAction(
                Notification.Action.Builder(
                    null,
                    ctx.getString(R.string.schedule_reminder_skip),
                    skipPending,
                ).build(),
            )
            .setAutoCancel(true)
            .build()
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID_BASE + scheduleId, notification)
        return Result.success()
    }

    companion object {
        const val CHANNEL_ID = "fokus_schedule"
        const val NOTIFICATION_ID_BASE = 2000

        fun ensureChannel(context: Context) {
            val manager = context
                .getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    context.getString(R.string.schedule_channel_name),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
    }
}

/** T: auto-start the session natively unless vetoed (skip / already live). */
class ScheduleStartWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        val ctx = applicationContext
        val scheduleId = inputData.getInt(ScheduleArmer.KEY_SCHEDULE_ID, -1)
        val occurrence = inputData.getLong(ScheduleArmer.KEY_OCCURRENCE_MS, 0L)
        val schedule = ScheduleStore.byId(ctx, scheduleId) ?: return Result.success()

        BlockedSetCache.ensureLoaded(ctx)
        val proceed = ScheduleLogic.shouldStart(
            skipMarker = ScheduleStore.skipMarker(ctx, scheduleId),
            occurrenceMs = occurrence,
            liveSessionId = BlockedSetCache.session?.id,
        )
        ScheduleStore.clearSkipMarker(ctx, scheduleId)

        if (proceed) {
            val now = System.currentTimeMillis()
            // Dismiss the reminder if still showing.
            (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(ScheduleReminderWorker.NOTIFICATION_ID_BASE + scheduleId)
            BlockedSetCache.setBlockedApps(ctx, schedule.packages)
            BlockedSetCache.startSession(
                ctx,
                NativeSessionConfig(
                    id = UUID.randomUUID().toString(),
                    endEpochMs = now + TimeUnit.MINUTES.toMillis(
                        schedule.durationMin.toLong(),
                    ),
                    taskAnchor = schedule.presetName,
                    strictMode = schedule.strictMode,
                    startedEpochMs = now,
                    recoveryEnabled = schedule.recoveryEnabled,
                ),
            )
            SessionForegroundService.start(ctx, restored = false)
            // Dart may be dead: the buffered restore event (with full config,
            // D-022) lets it synthesize the DB row on next attach.
            BlockedSetCache.session?.let { FokusEventBus.emitSessionRestored(it) }
        }

        // Always re-arm the next occurrence.
        ScheduleArmer.armNext(ctx, schedule)
        return Result.success()
    }
}

/** One-shot skip from the reminder notification. */
class ScheduleSkipReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val scheduleId = intent.getIntExtra(ScheduleArmer.KEY_SCHEDULE_ID, -1)
        val occurrence = intent.getLongExtra(ScheduleArmer.KEY_OCCURRENCE_MS, 0L)
        if (scheduleId == -1) return
        ScheduleStore.markSkipOnce(context, scheduleId, occurrence)
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .cancel(ScheduleReminderWorker.NOTIFICATION_ID_BASE + scheduleId)
    }
}
