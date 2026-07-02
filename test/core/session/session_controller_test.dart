import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/blocking_adapter.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/data/repositories/session_repository.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:fokus/core/session/session_machine.dart';

import '../data/test_db.dart';
import 'fake_blocking_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FokusDatabase db;
  late FakeBlockingAdapter fake;
  late ProviderContainer container;

  /// Mutable wall clock — every remaining-time value in the engine must be
  /// derived from this, never tick-accumulated.
  late DateTime now;
  final t0 = DateTime(2026, 7, 2, 9, 0);

  setUp(() {
    now = t0;
    db = testDb();
    fake = FakeBlockingAdapter();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      blockingAdapterProvider.overrideWithValue(fake),
      clockProvider.overrideWithValue(() => now),
      // No automatic ticks in tests — syncWithClock() is driven manually.
      tickerFactoryProvider.overrideWithValue((_) => const Stream.empty()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await fake.dispose();
    await db.close();
  });

  SessionController controller() =>
      container.read(sessionControllerProvider.notifier);
  SessionState state() => container.read(sessionControllerProvider);
  SessionRepository repo() => container.read(sessionRepositoryProvider);

  Future<String> startSession({int plannedMin = 30}) async {
    await controller().start(
      plannedMin: plannedMin,
      taskAnchor: 'write thesis chapter',
      strictMode: false,
    );
    return state().sessionId!;
  }

  group('start', () {
    test('arms native with the wall-clock anchor, persists, lands active',
        () async {
      final id = await startSession(plannedMin: 30);

      expect(state().status, SessionStatus.active);
      expect(state().remaining, const Duration(minutes: 30));
      expect(state().endTime, t0.add(const Duration(minutes: 30)));

      final config = fake.startedConfigs.single;
      expect(config.id, id);
      expect(
        config.endEpochMs,
        t0.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
      );
      expect(config.taskAnchor, 'write thesis chapter');
      expect(config.strictMode, isFalse);

      final row = await repo().getById(id);
      expect(row!.status, SessionStatus.active);
      expect(row.plannedMin, 30);
      expect(row.startTime, t0);
    });

    test('start while a session is active is an illegal transition',
        () async {
      await startSession();
      expect(
        () => controller().start(plannedMin: 15),
        throwsA(isA<IllegalSessionTransition>()),
      );
      expect(fake.startedConfigs, hasLength(1));
    });

    test('native failure rolls back to a fresh idle, no DB row', () async {
      fake.startError = StateError('channel dead');
      await expectLater(
        () => controller().start(plannedMin: 30),
        throwsA(isA<StateError>()),
      );
      expect(state().status, SessionStatus.idle);
      expect(await repo().getActiveSession(), isNull);
      // A later start must succeed from the fresh idle.
      fake.startError = null;
      await startSession();
      expect(state().status, SessionStatus.active);
    });
  });

  group('recovery', () {
    test('enterRecovery ⇄ resumeRecovery, both persisted', () async {
      final id = await startSession();

      await controller().enterRecovery();
      expect(state().status, SessionStatus.recoveryInProgress);
      expect((await repo().getById(id))!.status,
          SessionStatus.recoveryInProgress);

      await controller().resumeRecovery();
      expect(state().status, SessionStatus.active);
      expect((await repo().getById(id))!.status, SessionStatus.active);
    });

    test('recoveryRequested event enters recovery; replay is idempotent',
        () async {
      await startSession();

      fake.emit(const RecoveryRequestedEvent());
      await pumpEventQueue();
      expect(state().status, SessionStatus.recoveryInProgress);

      // Buffered replay of the same event — no error, no state change.
      fake.emit(const RecoveryRequestedEvent());
      await pumpEventQueue();
      expect(state().status, SessionStatus.recoveryInProgress);
    });

    test('resumeRecovery while active is an illegal transition', () async {
      await startSession();
      expect(
        () => controller().resumeRecovery(),
        throwsA(isA<IllegalSessionTransition>()),
      );
    });
  });

  group('wall-clock timer', () {
    test('remaining is derived from the clock, not accumulated', () async {
      await startSession(plannedMin: 30);

      now = t0.add(const Duration(minutes: 12, seconds: 30));
      await controller().syncWithClock();
      expect(
        state().remaining,
        const Duration(minutes: 17, seconds: 30),
      );
    });

    test('clock past endEpochMs → completed(timerEnd), anchored endTime',
        () async {
      final id = await startSession(plannedMin: 30);

      now = t0.add(const Duration(minutes: 42)); // overslept the end
      await controller().syncWithClock();

      expect(state().status, SessionStatus.completed);
      expect(state().completionReason, CompletionReason.timerEnd);
      expect(state().remaining, Duration.zero);
      expect(fake.stoppedSessionIds, contains(id));

      final row = await repo().getById(id);
      expect(row!.status, SessionStatus.completed);
      expect(row.completionReason, CompletionReason.timerEnd);
      expect(row.actualMin, 30);
      // endTime is the anchor, not "now" — retroactive detection keeps it.
      expect(row.endTime, t0.add(const Duration(minutes: 30)));
    });

    test('timer expiring mid-recovery composes resume → completed', () async {
      final id = await startSession(plannedMin: 30);
      await controller().enterRecovery();

      now = t0.add(const Duration(minutes: 31));
      await controller().syncWithClock();

      expect(state().status, SessionStatus.completed);
      expect((await repo().getById(id))!.status, SessionStatus.completed);
    });
  });

  group('user-driven endings', () {
    test('finishTask → completed(finishedTask) with elapsed actualMin',
        () async {
      final id = await startSession(plannedMin: 30);
      now = t0.add(const Duration(minutes: 7));

      await controller().finishTask();

      expect(state().status, SessionStatus.completed);
      expect(state().completionReason, CompletionReason.finishedTask);
      final row = await repo().getById(id);
      expect(row!.completionReason, CompletionReason.finishedTask);
      expect(row.actualMin, 7);
      expect(fake.stoppedSessionIds, contains(id));
    });

    test('finishTask from recovery composes resume → completed', () async {
      final id = await startSession();
      await controller().enterRecovery();

      await controller().finishTask();
      expect((await repo().getById(id))!.status, SessionStatus.completed);
    });

    test('emergency exit → aborted(emergency), no penalty side effects',
        () async {
      final id = await startSession(plannedMin: 30);
      now = t0.add(const Duration(minutes: 3));

      await controller().emergencyExit();

      expect(state().status, SessionStatus.aborted);
      expect(state().exitReason, ExitReason.emergency);
      final row = await repo().getById(id);
      expect(row!.status, SessionStatus.aborted);
      expect(row.exitReason, ExitReason.emergency);
      expect(row.actualMin, 3);
      expect(fake.stoppedSessionIds, contains(id));
    });

    test('exit-reason attempt is logged without ending the session',
        () async {
      final id = await startSession();
      await controller().recordExitReasonAttempt(ExitReason.tired);

      expect(state().status, SessionStatus.active);
      expect((await repo().getById(id))!.exitReason, ExitReason.tired);
    });
  });

  group('permissionLost', () {
    test('mid-session → failedPermissions + notice + native stop', () async {
      final id = await startSession();
      now = t0.add(const Duration(minutes: 5));

      fake.emit(const PermissionLostEvent(kind: PermissionKind.accessibility));
      await pumpEventQueue();

      expect(state().status, SessionStatus.failedPermissions);
      expect(state().lostPermission, PermissionKind.accessibility);
      final row = await repo().getById(id);
      expect(row!.status, SessionStatus.failedPermissions);
      expect(row.actualMin, 5);
      expect(fake.stoppedSessionIds, contains(id));
    });

    test('mid-recovery composes resume → failedPermissions', () async {
      final id = await startSession();
      await controller().enterRecovery();

      fake.emit(const PermissionLostEvent(kind: PermissionKind.accessibility));
      await pumpEventQueue();

      expect(state().status, SessionStatus.failedPermissions);
      expect(
          (await repo().getById(id))!.status, SessionStatus.failedPermissions);
    });

    test('with no live session → notice only, replay-safe', () async {
      controller(); // build with empty DB
      fake.emit(const PermissionLostEvent(kind: PermissionKind.usageStats));
      fake.emit(const PermissionLostEvent(kind: PermissionKind.usageStats));
      await pumpEventQueue();

      expect(state().status, SessionStatus.idle);
      expect(state().lostPermission, PermissionKind.usageStats);

      controller().clearNotice();
      expect(state().lostPermission, isNull);
    });
  });

  group('distractionAttempt', () {
    Future<List<DistractionAttempt>> attemptRows() =>
        db.select(db.distractionAttempts).get();

    test('writes a row with the original ts; replay writes exactly once',
        () async {
      final id = await startSession();
      final ts = t0.add(const Duration(minutes: 2));

      final event = DistractionAttemptEvent(
        packageName: 'com.instagram.android',
        ts: ts,
        seq: 0,
      );
      fake.emit(event);
      fake.emit(event); // journalled replay — same pkg, same original ts
      await pumpEventQueue();

      final rows = await attemptRows();
      expect(rows, hasLength(1));
      expect(rows.single.sessionId, id);
      expect(rows.single.packageName, 'com.instagram.android');
      expect(rows.single.ts, ts);
      // D-013 P1-A: both deliveries ack the journal seq so native drops it.
      expect(fake.ackedSeqs, [0, 0]);
    });

    test('replay after retroactive completion attributes by ts window',
        () async {
      final id = await startSession(plannedMin: 30);
      final ts = t0.add(const Duration(minutes: 10));

      // App was dead: session completes retroactively first, the journalled
      // attempt arrives after.
      now = t0.add(const Duration(minutes: 45));
      await controller().syncWithClock();
      expect(state().status, SessionStatus.completed);

      fake.emit(
        DistractionAttemptEvent(packageName: 'com.tiktok', ts: ts, seq: 3),
      );
      await pumpEventQueue();

      final rows = await attemptRows();
      expect(rows.single.sessionId, id);
      expect(fake.ackedSeqs, contains(3));
    });

    test(
        'D-013 P1-D: buffered attempt from a dead session is NOT misattributed '
        'to a newer session (window containment only)', () async {
      // Session A: t0 .. t0+30. An attempt happens at t0+5 but its journalled
      // delivery is delayed. A then completes on its timer at t0+30.
      final idA = await startSession(plannedMin: 30);
      final tsA = t0.add(const Duration(minutes: 5));
      now = t0.add(const Duration(minutes: 30));
      await controller().syncWithClock(); // A completes (endTime = t0+30)
      expect(state().status, SessionStatus.completed);

      // Later, a NEW session B starts and is the "most recent" row.
      now = t0.add(const Duration(minutes: 40));
      await controller().start(plannedMin: 30, taskAnchor: 'B');
      final idB = state().sessionId!;
      expect(idB, isNot(idA));

      // The old buffered attempt (tsA, inside A's window [t0, t0+31], OUTSIDE
      // B's window [t0+40, t0+71]) now replays. It must attach to A, never B —
      // the old getMostRecentSession() path would have wrongly picked B.
      fake.emit(
        DistractionAttemptEvent(packageName: 'com.reddit', ts: tsA, seq: 7),
      );
      await pumpEventQueue();

      final rows = await attemptRows();
      expect(rows.single.sessionId, idA); // correct owner
      expect(rows.single.sessionId, isNot(idB)); // not the newer session
    });

    test('orphan attempt (no session window contains ts) is dropped + acked',
        () async {
      controller(); // build with empty DB
      fake.emit(
        DistractionAttemptEvent(packageName: 'com.x', ts: t0, seq: 0),
      );
      await pumpEventQueue();

      expect(await attemptRows(), isEmpty);
      // Acked anyway so the journal never replays a permanently-orphan event.
      expect(fake.ackedSeqs, [0]);
    });

    test('recoveryRequested is acked once handled', () async {
      await startSession();
      fake.emit(const RecoveryRequestedEvent(seq: 2));
      await pumpEventQueue();
      expect(state().status, SessionStatus.recoveryInProgress);
      expect(fake.ackedSeqs, contains(2));
    });
  });

  group('stopMismatch (D-013 P1-C)', () {
    test('mismatch on the tracked live session aborts it (Dart wins)',
        () async {
      final id = await startSession(plannedMin: 30);
      now = t0.add(const Duration(minutes: 3));

      // Native reports it dropped session `id` because Dart stopped some other
      // id → Dart's arming for `id` is gone, so it must terminate `id`.
      fake.emit(StopMismatchEvent(requestedId: 'other-session', liveId: id));
      await pumpEventQueue();

      expect(state().status, SessionStatus.aborted);
      expect(state().exitReason, ExitReason.stuck);
      expect((await repo().getById(id))!.status, SessionStatus.aborted);
    });

    test('mismatch for a session we are not tracking is a logged no-op',
        () async {
      final id = await startSession(plannedMin: 30);

      fake.emit(
        const StopMismatchEvent(requestedId: 'x', liveId: 'some-dead-session'),
      );
      await pumpEventQueue();

      // Our live session is untouched.
      expect(state().status, SessionStatus.active);
      expect(state().sessionId, id);
    });
  });

  group('restore & reconcile', () {
    test('sessionRestored re-hydrates a live session from the DB', () async {
      final start = t0.subtract(const Duration(minutes: 10));
      await repo().createSession(
        id: 'restored-1',
        plannedMin: 30,
        strictMode: true,
        taskAnchor: 'deep work',
        startTime: start,
      );

      controller(); // build first: subscribes before the event, like app boot
      fake.emit(const SessionRestoredEvent(sessionId: 'restored-1'));
      await pumpEventQueue();

      expect(state().status, SessionStatus.active);
      expect(state().sessionId, 'restored-1');
      expect(state().strictMode, isTrue);
      expect(state().taskAnchor, 'deep work');
      expect(state().remaining, const Duration(minutes: 20));
    });

    test('endEpochMs passed while dead → completed retroactively', () async {
      final start = t0.subtract(const Duration(minutes: 90));
      await repo().createSession(
        id: 'restored-2',
        plannedMin: 30,
        strictMode: false,
        startTime: start,
      );

      controller(); // build first: subscribes before the event, like app boot
      fake.emit(const SessionRestoredEvent(sessionId: 'restored-2'));
      await pumpEventQueue();

      expect(state().status, SessionStatus.completed);
      expect(state().completionReason, CompletionReason.timerEnd);
      final row = await repo().getById('restored-2');
      expect(row!.status, SessionStatus.completed);
      expect(row.actualMin, 30);
      expect(row.endTime, start.add(const Duration(minutes: 30)));
      expect(fake.stoppedSessionIds, contains('restored-2'));
    });

    test('replayed sessionRestored for the tracked session is a no-op',
        () async {
      final id = await startSession();

      fake.emit(SessionRestoredEvent(sessionId: id));
      fake.emit(SessionRestoredEvent(sessionId: id));
      await pumpEventQueue();

      expect(state().status, SessionStatus.active);
      expect(state().sessionId, id);
    });

    test('sessionRestored for a DB-terminal session only disarms native',
        () async {
      await repo().createSession(
        id: 'stale-1',
        plannedMin: 15,
        strictMode: false,
        startTime: t0.subtract(const Duration(hours: 2)),
      );
      await repo().abortSession(
        'stale-1',
        exitReason: ExitReason.emergency,
        actualMin: 5,
      );

      controller(); // build first: subscribes before the event, like app boot
      fake.emit(const SessionRestoredEvent(sessionId: 'stale-1'));
      await pumpEventQueue();

      expect(state().status, SessionStatus.idle);
      expect(fake.stoppedSessionIds, contains('stale-1'));
    });

    test('cold start with no event still hydrates the active session',
        () async {
      final start = t0.subtract(const Duration(minutes: 5));
      await repo().createSession(
        id: 'cold-1',
        plannedMin: 60,
        strictMode: false,
        startTime: start,
      );

      controller(); // first read = build → bootstrap hydration
      await pumpEventQueue();

      expect(state().status, SessionStatus.active);
      expect(state().sessionId, 'cold-1');
      expect(state().remaining, const Duration(minutes: 55));
    });

    test('hydration adopts recoveryInProgress as-is', () async {
      final start = t0.subtract(const Duration(minutes: 5));
      await repo().createSession(
        id: 'rec-1',
        plannedMin: 60,
        strictMode: false,
        startTime: start,
      );
      await repo().setStatus('rec-1', SessionStatus.recoveryInProgress);

      controller(); // build first: subscribes before the event, like app boot
      fake.emit(const SessionRestoredEvent(sessionId: 'rec-1'));
      await pumpEventQueue();

      expect(state().status, SessionStatus.recoveryInProgress);
    });
  });
}
