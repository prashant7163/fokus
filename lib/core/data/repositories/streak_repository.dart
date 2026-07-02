import 'package:drift/drift.dart';

import '../database.dart';

/// Data access for the `streak_summary` singleton row.
///
/// Pure persistence — streak *rules* (qualifying sessions, day boundaries,
/// D-011 preserve-vs-earn semantics) live in the streak calculator (F-09).
class StreakRepository {
  StreakRepository(this._db);

  final FokusDatabase _db;

  /// Returns the singleton row, creating it (all zeros) on first access.
  Future<StreakSummaryData> getSummary() async {
    await _db.into(_db.streakSummary).insert(
          const StreakSummaryCompanion(id: Value(1)),
          mode: InsertMode.insertOrIgnore,
        );
    return _db.select(_db.streakSummary).getSingle();
  }

  Stream<StreakSummaryData?> watchSummary() =>
      (_db.select(_db.streakSummary)..limit(1)).watchSingleOrNull();

  /// Persists new values. Only touches the fields passed in.
  Future<void> updateSummary({
    int? currentDays,
    int? longestDays,
    DateTime? lastFocusDate,
    int? tokensAvailable,
    int? tokensLifetime,
  }) async {
    await getSummary(); // ensure the row exists
    await (_db.update(_db.streakSummary)..where((s) => s.id.equals(1))).write(
      StreakSummaryCompanion(
        currentDays:
            currentDays == null ? const Value.absent() : Value(currentDays),
        longestDays:
            longestDays == null ? const Value.absent() : Value(longestDays),
        lastFocusDate: lastFocusDate == null
            ? const Value.absent()
            : Value(lastFocusDate),
        tokensAvailable: tokensAvailable == null
            ? const Value.absent()
            : Value(tokensAvailable),
        tokensLifetime: tokensLifetime == null
            ? const Value.absent()
            : Value(tokensLifetime),
      ),
    );
  }
}
