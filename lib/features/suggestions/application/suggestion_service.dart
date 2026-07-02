import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database.dart';
import '../../../core/data/providers.dart';
import '../../../core/prefs.dart';
import '../../../core/session/session_controller.dart' show clockProvider;
import 'suggestion_engine.dart';

/// Today's suggestion, if any — null when opted out, gated by history, or
/// already dismissed today.
class TodaysSuggestion {
  const TodaysSuggestion({
    required this.id,
    required this.type,
    this.hour,
    this.minutes,
  });

  final int id;
  final String type;
  final int? hour;
  final int? minutes;
}

/// Smart Suggestions (F-17, spec §3.10): opt-in, rule-based, on-device, max
/// ONE per day, always dismissible, always explained. `ai_insights` rows
/// (CONTRACTS §3) are the audit trail: generatedAt = the daily cap,
/// shownAt = user acknowledged/dismissed, actedOn = tapped the action.
class SuggestionService {
  SuggestionService(this._db, this._now, this._optedIn);

  final FokusDatabase _db;
  final DateTime Function() _now;
  final bool _optedIn;

  Future<TodaysSuggestion?> todaysSuggestion() async {
    if (!_optedIn) return null;
    final now = _now();
    final dayStart = DateTime(now.year, now.month, now.day);

    // Daily cap: reuse today's insight; dismissed (shownAt set) → nothing.
    final existing = await (_db.select(_db.aiInsights)
          ..where((i) => i.generatedAt.isBiggerOrEqualValue(dayStart))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      if (existing.shownAt != null) return null;
      return _fromRow(existing);
    }

    // History gate (≥ 14 days of data).
    final sessions = await _db.select(_db.focusSessions).get();
    if (sessions.isEmpty) return null;
    final oldest = sessions
        .map((s) => s.startTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    if (!SuggestionEngine.hasEnoughHistory(oldest, now)) return null;

    // Rules in priority order; first hit wins today's single slot.
    Suggestion? suggestion;
    final attempts = await _db.select(_db.distractionAttempts).get();
    final windowHour = SuggestionEngine.distractionWindow(
      [for (final a in attempts) a.ts],
      now,
    );
    if (windowHour != null) {
      suggestion = Suggestion.distractionWindow(windowHour);
    } else {
      final length = SuggestionEngine.optimalLength([
        for (final s in sessions)
          if (s.status == SessionStatus.completed ||
              s.status == SessionStatus.aborted)
            SessionFact(
              plannedMin: s.plannedMin,
              completed: s.status == SessionStatus.completed,
              startTime: s.startTime,
            ),
      ]);
      if (length != null) suggestion = Suggestion.optimalLength(length);
    }
    if (suggestion == null) return null;

    final id = await _db.into(_db.aiInsights).insert(
          AiInsightsCompanion.insert(
            type: suggestion.type,
            contentJson: jsonEncode({
              'hour': suggestion.hour,
              'minutes': suggestion.minutes,
            }),
            generatedAt: now,
          ),
        );
    return TodaysSuggestion(
      id: id,
      type: suggestion.type,
      hour: suggestion.hour,
      minutes: suggestion.minutes,
    );
  }

  TodaysSuggestion _fromRow(AiInsight row) {
    final content = jsonDecode(row.contentJson) as Map<String, dynamic>;
    return TodaysSuggestion(
      id: row.id,
      type: row.type,
      hour: content['hour'] as int?,
      minutes: content['minutes'] as int?,
    );
  }

  /// Dismiss (or acknowledge): the card disappears for the day.
  Future<void> dismiss(int id, {bool actedOn = false}) async {
    await (_db.update(_db.aiInsights)..where((i) => i.id.equals(id))).write(
      AiInsightsCompanion(
        shownAt: Value(_now()),
        actedOn: Value(actedOn),
      ),
    );
  }

  /// Personal recovery ordering for the hub (rule 3) — null when opted out
  /// or nothing has ≥ 5 samples (default order applies).
  Future<List<RecoveryType>?> recoveryOrder() async {
    if (!_optedIn) return null;
    final events = await (_db.select(_db.recoveryEvents)
          ..where((e) => e.result.isNotNull()))
        .get();
    final stats = <RecoveryType, ({int resumed, int total})>{};
    for (final e in events) {
      final prev = stats[e.type] ?? (resumed: 0, total: 0);
      stats[e.type] = (
        resumed: prev.resumed +
            (e.result == RecoveryResult.resumed ? 1 : 0),
        total: prev.total + 1,
      );
    }
    final order = SuggestionEngine.recoveryOrder(stats);
    return order;
  }
}

final suggestionServiceProvider = Provider<SuggestionService>(
  (ref) => SuggestionService(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
    ref.watch(smartSuggestionsProvider),
  ),
);

final todaysSuggestionProvider =
    FutureProvider.autoDispose<TodaysSuggestion?>(
  (ref) => ref.watch(suggestionServiceProvider).todaysSuggestion(),
);

/// Hub module ordering (rule 3). Falls back to the default order.
final recoveryOrderProvider =
    FutureProvider.autoDispose<List<RecoveryType>?>(
  (ref) => ref.watch(suggestionServiceProvider).recoveryOrder(),
);
