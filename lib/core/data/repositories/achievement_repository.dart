import 'package:drift/drift.dart';

import '../database.dart';

/// Data access for `achievements` (CONTRACTS §3). Pure persistence — trigger
/// evaluation lives in the F-15 achievement engine, not here.
class AchievementRepository {
  AchievementRepository(this._db);

  final FokusDatabase _db;

  /// All unlocked rows, oldest unlock first — badge-screen input.
  Future<List<Achievement>> getAll() => (_db.select(_db.achievements)
        ..orderBy([(a) => OrderingTerm.asc(a.unlockedAt)]))
      .get();

  Future<Set<String>> unlockedCodes() async =>
      (await _db.select(_db.achievements).get()).map((a) => a.code).toSet();

  /// Unlocks [code] once. Returns true only for the call that actually
  /// inserted the row — a replay (row already present) returns false and
  /// leaves the original `unlockedAt` untouched.
  Future<bool> insertIfAbsent(String code, DateTime unlockedAt) async {
    final inserted = await _db.into(_db.achievements).insertReturningOrNull(
          AchievementsCompanion.insert(code: code, unlockedAt: unlockedAt),
          mode: InsertMode.insertOrIgnore,
        );
    return inserted != null;
  }
}
