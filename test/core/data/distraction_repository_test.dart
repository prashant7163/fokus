import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/repositories/distraction_repository.dart';
import 'package:fokus/core/data/repositories/session_repository.dart';

import 'test_db.dart';

void main() {
  late FokusDatabase db;
  late DistractionRepository repo;
  late String sessionId;

  setUp(() async {
    db = testDb();
    repo = DistractionRepository(db);
    sessionId = await SessionRepository(db)
        .createSession(plannedMin: 30, strictMode: false);
  });

  tearDown(() => db.close());

  test('logAttempt writes a row linked to the session', () async {
    await repo.logAttempt(
      sessionId: sessionId,
      packageName: 'com.instagram.android',
      ts: DateTime(2026, 7, 2, 9, 15),
    );

    final attempts = await repo.attemptsForSession(sessionId);
    expect(attempts, hasLength(1));
    expect(attempts.single.packageName, 'com.instagram.android');
    expect(attempts.single.recoveryInvoked, isFalse);
  });

  test('foreign key: attempts require an existing session', () {
    expect(
      () => repo.logAttempt(sessionId: 'ghost', packageName: 'com.x'),
      throwsA(anything),
    );
  });

  test('markRecoveryInvoked flips the flag', () async {
    final id = await repo.logAttempt(
        sessionId: sessionId, packageName: 'com.tiktok');

    await repo.markRecoveryInvoked(id);

    final attempts = await repo.attemptsForSession(sessionId);
    expect(attempts.single.recoveryInvoked, isTrue);
  });

  test('countForSession counts only this session', () async {
    final other = await SessionRepository(db)
        .createSession(plannedMin: 15, strictMode: false);
    await repo.logAttempt(sessionId: sessionId, packageName: 'com.a');
    await repo.logAttempt(sessionId: sessionId, packageName: 'com.b');
    await repo.logAttempt(sessionId: other, packageName: 'com.a');

    expect(await repo.countForSession(sessionId), 2);
    expect(await repo.countForSession(other), 1);
  });

  test('watchCountForSession emits live count', () async {
    final counts = <int>[];
    final sub = repo.watchCountForSession(sessionId).listen(counts.add);

    await repo.logAttempt(sessionId: sessionId, packageName: 'com.a');
    await repo.logAttempt(sessionId: sessionId, packageName: 'com.b');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();

    expect(counts, contains(2));
  });

  test('attemptsSince supports the ≥3-in-5-min proactive rule', () async {
    final base = DateTime(2026, 7, 2, 9);
    for (final minute in [0, 1, 3, 10]) {
      await repo.logAttempt(
        sessionId: sessionId,
        packageName: 'com.x',
        ts: base.add(Duration(minutes: minute)),
      );
    }

    final recent = await repo.attemptsSince(
      sessionId,
      base.add(const Duration(minutes: 10 - 5)),
    );
    expect(recent, hasLength(1)); // only the minute-10 attempt

    final all = await repo.attemptsSince(sessionId, base);
    expect(all, hasLength(4));
  });
}
