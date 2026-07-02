import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/repositories/session_repository.dart';

import 'test_db.dart';

void main() {
  late FokusDatabase db;
  late SessionRepository repo;

  setUp(() {
    db = testDb();
    repo = SessionRepository(db);
  });

  tearDown(() => db.close());

  test('createSession inserts an active session with the given config',
      () async {
    final start = DateTime(2026, 7, 2, 9);
    final id = await repo.createSession(
      plannedMin: 30,
      strictMode: true,
      taskAnchor: 'Write thesis chapter',
      startTime: start,
    );

    final session = await repo.getById(id);
    expect(session, isNotNull);
    expect(session!.status, SessionStatus.active);
    expect(session.plannedMin, 30);
    expect(session.strictMode, isTrue);
    expect(session.taskAnchor, 'Write thesis chapter');
    expect(session.startTime, start);
    expect(session.endTime, isNull);
    expect(session.actualMin, isNull);
    expect(session.completionReason, isNull);
    expect(session.exitReason, isNull);
  });

  test('ids are unique per session', () async {
    final a = await repo.createSession(plannedMin: 15, strictMode: false);
    final b = await repo.createSession(plannedMin: 15, strictMode: false);
    expect(a, isNot(equals(b)));
  });

  test('completeSession sets terminal state, reason, actualMin, endTime',
      () async {
    final id = await repo.createSession(plannedMin: 60, strictMode: false);
    final end = DateTime(2026, 7, 2, 10);

    await repo.completeSession(
      id,
      reason: CompletionReason.timerEnd,
      actualMin: 60,
      endTime: end,
    );

    final session = await repo.getById(id);
    expect(session!.status, SessionStatus.completed);
    expect(session.completionReason, CompletionReason.timerEnd);
    expect(session.actualMin, 60);
    expect(session.endTime, end);
  });

  test('abortSession records the structured exit reason', () async {
    final id = await repo.createSession(plannedMin: 30, strictMode: false);

    await repo.abortSession(id,
        exitReason: ExitReason.emergency, actualMin: 5);

    final session = await repo.getById(id);
    expect(session!.status, SessionStatus.aborted);
    expect(session.exitReason, ExitReason.emergency);
    expect(session.actualMin, 5);
    expect(session.endTime, isNotNull);
  });

  test('failSessionPermissions is a distinct terminal state', () async {
    final id = await repo.createSession(plannedMin: 30, strictMode: false);

    await repo.failSessionPermissions(id, actualMin: 12);

    final session = await repo.getById(id);
    expect(session!.status, SessionStatus.failedPermissions);
    expect(session.completionReason, isNull);
  });

  test('setStatus supports active ⇄ recoveryInProgress', () async {
    final id = await repo.createSession(plannedMin: 30, strictMode: false);

    await repo.setStatus(id, SessionStatus.recoveryInProgress);
    expect((await repo.getById(id))!.status, SessionStatus.recoveryInProgress);

    await repo.setStatus(id, SessionStatus.active);
    expect((await repo.getById(id))!.status, SessionStatus.active);
  });

  test('setExitReason logs an attempt without ending the session', () async {
    final id = await repo.createSession(plannedMin: 30, strictMode: true);

    await repo.setExitReason(id, ExitReason.needApp);

    final session = await repo.getById(id);
    expect(session!.exitReason, ExitReason.needApp);
    expect(session.status, SessionStatus.active);
  });

  test('getActiveSession finds active and recoveryInProgress, not terminal',
      () async {
    expect(await repo.getActiveSession(), isNull);

    final id = await repo.createSession(plannedMin: 30, strictMode: false);
    expect((await repo.getActiveSession())!.id, id);

    await repo.setStatus(id, SessionStatus.recoveryInProgress);
    expect((await repo.getActiveSession())!.id, id);

    await repo.completeSession(id,
        reason: CompletionReason.finishedTask, actualMin: 20);
    expect(await repo.getActiveSession(), isNull);
  });

  test('watchActiveSession emits on transitions', () async {
    final emissions = <String?>[];
    final sub =
        repo.watchActiveSession().listen((s) => emissions.add(s?.id));

    final id = await repo.createSession(plannedMin: 30, strictMode: false);
    await repo.completeSession(id,
        reason: CompletionReason.timerEnd, actualMin: 30);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();

    expect(emissions, containsAllInOrder(<String?>[id, null]));
  });

  test('sessionsBetween returns [from, to) ordered by startTime', () async {
    Future<String> at(DateTime t) =>
        repo.createSession(plannedMin: 15, strictMode: false, startTime: t);

    await at(DateTime(2026, 7, 1, 23, 59));
    final b = await at(DateTime(2026, 7, 2, 8));
    final c = await at(DateTime(2026, 7, 2, 20));
    await at(DateTime(2026, 7, 3, 0, 0));

    final day = await repo.sessionsBetween(
      DateTime(2026, 7, 2),
      DateTime(2026, 7, 3),
    );
    expect(day.map((s) => s.id).toList(), [b, c]);
  });

  test('getMostRecentSession returns latest start for one-tap repeat',
      () async {
    await repo.createSession(
        plannedMin: 15, strictMode: false, startTime: DateTime(2026, 7, 1));
    final latest = await repo.createSession(
        plannedMin: 120, strictMode: true, startTime: DateTime(2026, 7, 2));

    expect((await repo.getMostRecentSession())!.id, latest);
  });

  test('sessionsStartedBefore returns already-started sessions newest-first',
      () async {
    final a = await repo.createSession(
        plannedMin: 30, strictMode: false, startTime: DateTime(2026, 7, 2, 9));
    final b = await repo.createSession(
        plannedMin: 30, strictMode: false, startTime: DateTime(2026, 7, 2, 10));
    // Started after the query ts → excluded.
    await repo.createSession(
        plannedMin: 30, strictMode: false, startTime: DateTime(2026, 7, 2, 12));

    final rows = await repo.sessionsStartedBefore(DateTime(2026, 7, 2, 11));
    expect(rows.map((s) => s.id).toList(), [b, a]); // newest first, no future
  });

  test('updating a nonexistent session throws', () {
    expect(
      () => repo.setStatus('missing', SessionStatus.active),
      throwsStateError,
    );
  });
}
