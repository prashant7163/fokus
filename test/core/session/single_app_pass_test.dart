import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/providers.dart';
import 'package:fokus/core/session/session_controller.dart';

import '../data/test_db.dart';
import 'fake_blocking_adapter.dart';

/// F-08 single-app pass ("need one app", non-strict): wall-clock anchored,
/// never a pause, never available in strict mode, never outlives the session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FokusDatabase db;
  late FakeBlockingAdapter fake;
  late ProviderContainer container;
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

  Future<void> start({int plannedMin = 30, bool strictMode = false}) =>
      controller().start(plannedMin: plannedMin, strictMode: strictMode);

  test('grants 5 minutes from now, timer keeps running', () async {
    await start(plannedMin: 30);
    now = t0.add(const Duration(minutes: 10));

    await controller().grantAppPass('com.spotify.music');

    final expectedEnd = now.add(const Duration(minutes: 5));
    final granted = fake.grantedPasses.single;
    expect(granted.packageName, 'com.spotify.music');
    expect(granted.endEpochMs, expectedEnd.millisecondsSinceEpoch);

    expect(state().passPackage, 'com.spotify.music');
    expect(state().passEndTime, expectedEnd);
    expect(state().hasActivePass, isTrue);
    // Never a pause (D-011): the session anchor is untouched.
    expect(state().status, SessionStatus.active);
    expect(state().endTime, t0.add(const Duration(minutes: 30)));
  });

  test('pass never outlives the session (clamped to session end)', () async {
    await start(plannedMin: 30);
    now = t0.add(const Duration(minutes: 28));

    await controller().grantAppPass('com.spotify.music');

    final sessionEnd = t0.add(const Duration(minutes: 30));
    expect(fake.grantedPasses.single.endEpochMs,
        sessionEnd.millisecondsSinceEpoch);
    expect(state().passEndTime, sessionEnd);
  });

  test('strict mode is a programming error, nothing is granted', () async {
    await start(strictMode: true);

    await expectLater(
      controller().grantAppPass('com.spotify.music'),
      throwsStateError,
    );
    expect(fake.grantedPasses, isEmpty);
    expect(state().hasActivePass, isFalse);
  });

  test('no-op without a running session', () async {
    await controller().grantAppPass('com.spotify.music');
    expect(fake.grantedPasses, isEmpty);
  });

  test('composes resume when granted mid-recovery', () async {
    await start();
    await controller().enterRecovery();

    await controller().grantAppPass('com.spotify.music');

    // The user is heading to the passed app with the session live — recovery
    // is over (its event was already closed by the recovery controller).
    expect(state().status, SessionStatus.active);
    expect(state().hasActivePass, isTrue);
  });

  test('expires by wall clock on the next tick', () async {
    await start(plannedMin: 30);
    await controller().grantAppPass('com.spotify.music');

    now = t0.add(const Duration(minutes: 4, seconds: 59));
    await controller().syncWithClock();
    expect(state().hasActivePass, isTrue);

    now = t0.add(const Duration(minutes: 5));
    await controller().syncWithClock();
    expect(state().hasActivePass, isFalse);
    expect(state().passPackage, isNull);
    expect(state().passEndTime, isNull);
    // Session unaffected.
    expect(state().status, SessionStatus.active);
  });

  test('a terminal transition clears the pass', () async {
    await start();
    await controller().grantAppPass('com.spotify.music');

    await controller().emergencyExit();

    expect(state().status, SessionStatus.aborted);
    expect(state().hasActivePass, isFalse);
  });

  test('shrink drops the pass with the re-anchor (native drops it too)',
      () async {
    await start(plannedMin: 60);
    await controller().grantAppPass('com.spotify.music');

    await controller().shrinkTo();

    // shrinkTo re-arms natively with the same id; BlockedSetCache.startSession
    // clears the native pass, and the fresh Dart state mirrors that.
    expect(state().hasActivePass, isFalse);
  });

  test('a new grant replaces the old (one pass at a time)', () async {
    await start();
    await controller().grantAppPass('com.spotify.music');
    now = t0.add(const Duration(minutes: 1));
    await controller().grantAppPass('com.google.android.apps.maps');

    expect(fake.grantedPasses, hasLength(2));
    expect(state().passPackage, 'com.google.android.apps.maps');
    expect(
      state().passEndTime,
      now.add(const Duration(minutes: 5)),
    );
  });
}
