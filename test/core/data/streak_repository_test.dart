import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/repositories/streak_repository.dart';

import 'test_db.dart';

void main() {
  late FokusDatabase db;
  late StreakRepository repo;

  setUp(() {
    db = testDb();
    repo = StreakRepository(db);
  });

  tearDown(() => db.close());

  test('first read creates the singleton row with zeros', () async {
    final summary = await repo.getSummary();

    expect(summary.id, 1);
    expect(summary.currentDays, 0);
    expect(summary.longestDays, 0);
    expect(summary.lastFocusDate, isNull);
    expect(summary.tokensAvailable, 0);
    expect(summary.tokensLifetime, 0);
  });

  test('repeated reads never create a second row', () async {
    await repo.getSummary();
    await repo.getSummary();

    final rows = await db.select(db.streakSummary).get();
    expect(rows, hasLength(1));
  });

  test('updateSummary persists only the passed fields', () async {
    await repo.updateSummary(currentDays: 7, tokensAvailable: 1);
    await repo.updateSummary(longestDays: 7);

    final summary = await repo.getSummary();
    expect(summary.currentDays, 7);
    expect(summary.longestDays, 7);
    expect(summary.tokensAvailable, 1);
    expect(summary.tokensLifetime, 0);
    expect(summary.lastFocusDate, isNull);
  });

  test('updateSummary works before any explicit getSummary', () async {
    await repo.updateSummary(
      currentDays: 3,
      lastFocusDate: DateTime(2026, 7, 2),
    );

    final summary = await repo.getSummary();
    expect(summary.currentDays, 3);
    expect(summary.lastFocusDate, DateTime(2026, 7, 2));
  });

  test('singleton CHECK rejects any row with id != 1', () async {
    await repo.getSummary(); // creates the id=1 row

    expect(
      () => db
          .into(db.streakSummary)
          .insert(const StreakSummaryCompanion(id: Value(2))),
      throwsA(anything), // SQLite CHECK violation surfaces as an exception
    );
  });

  test('watchSummary emits updates', () async {
    await repo.getSummary();
    final emissions = <int>[];
    final sub = repo
        .watchSummary()
        .listen((s) => emissions.add(s?.currentDays ?? -1));

    await repo.updateSummary(currentDays: 5);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();

    expect(emissions, contains(5));
  });
}
