import 'package:drift/drift.dart';

import '../database.dart';

/// Data access for `feedback_entries` (CONTRACTS §3, F-16). Local-only —
/// stored, never transmitted (fokus-specs §3.9).
class FeedbackRepository {
  FeedbackRepository(this._db);

  final FokusDatabase _db;

  /// Post-session micro-feedback. [rating]: 1 = rough, 2 = okay, 3 = good.
  /// [reason] is the 😔 follow-up code (tooLong | interrupted |
  /// blockingFailed | other), null otherwise.
  Future<int> addPostSession({
    required int rating,
    String? reason,
    String? contextJson,
    DateTime? createdAt,
  }) =>
      _db.into(_db.feedbackEntries).insert(
            FeedbackEntriesCompanion.insert(
              type: 'post_session',
              rating: Value(rating),
              feedbackText: Value(reason),
              contextJson: Value(contextJson),
              createdAt: createdAt ?? DateTime.now(),
            ),
          );

  Future<List<FeedbackEntry>> all() => (_db.select(_db.feedbackEntries)
        ..orderBy([(f) => OrderingTerm.asc(f.createdAt)]))
      .get();

  /// Whether feedback was already recorded for [sessionId] — guards a
  /// rebuilt complete screen from double-asking.
  Future<bool> existsForSession(String sessionId) async {
    final rows = await (_db.select(_db.feedbackEntries)
          ..where((f) => f.contextJson.like('%"$sessionId"%')))
        .get();
    return rows.isNotEmpty;
  }
}
