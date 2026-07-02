import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/repositories/recovery_repository.dart';
import 'package:fokus/core/data/repositories/session_repository.dart';

import 'test_db.dart';

void main() {
  late FokusDatabase db;
  late RecoveryRepository repo;
  late String sessionId;

  setUp(() async {
    db = testDb();
    repo = RecoveryRepository(db);
    sessionId = await SessionRepository(db)
        .createSession(plannedMin: 30, strictMode: false);
  });

  tearDown(() => db.close());

  test('startEvent logs an in-progress event (no result yet)', () async {
    await repo.startEvent(sessionId: sessionId, type: RecoveryType.breathe);

    final events = await repo.eventsForSession(sessionId);
    expect(events, hasLength(1));
    expect(events.single.type, RecoveryType.breathe);
    expect(events.single.result, isNull);
    expect(events.single.completedAt, isNull);
  });

  test('completeEvent records resumed', () async {
    final id = await repo.startEvent(
        sessionId: sessionId, type: RecoveryType.taskReset);

    await repo.completeEvent(id, result: RecoveryResult.resumed);

    final event = (await repo.eventsForSession(sessionId)).single;
    expect(event.result, RecoveryResult.resumed);
    expect(event.completedAt, isNotNull);
  });

  test('completeEvent records exited', () async {
    final id = await repo.startEvent(
        sessionId: sessionId, type: RecoveryType.changeDuration);

    await repo.completeEvent(id, result: RecoveryResult.exited);

    expect((await repo.eventsForSession(sessionId)).single.result,
        RecoveryResult.exited);
  });

  test('all five contract recovery types round-trip', () async {
    for (final type in RecoveryType.values) {
      final id = await repo.startEvent(sessionId: sessionId, type: type);
      await repo.completeEvent(id, result: RecoveryResult.resumed);
    }

    final events = await repo.eventsForSession(sessionId);
    expect(events.map((e) => e.type), containsAll(RecoveryType.values));
  });

  test('completedEvents excludes in-progress ones', () async {
    final done = await repo.startEvent(
        sessionId: sessionId, type: RecoveryType.water);
    await repo.completeEvent(done, result: RecoveryResult.resumed);
    await repo.startEvent(sessionId: sessionId, type: RecoveryType.stretch);

    final completed = await repo.completedEvents();
    expect(completed, hasLength(1));
    expect(completed.single.type, RecoveryType.water);
  });

  test('completing a nonexistent event throws', () {
    expect(
      () => repo.completeEvent(999, result: RecoveryResult.resumed),
      throwsStateError,
    );
  });
}
