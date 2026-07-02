/// Drift table definitions — binding schema per docs/CONTRACTS.md §3.
/// Column additions/renames require a DECISIONS.md entry.
library;

import 'package:drift/drift.dart';

import '../constants.dart';
import 'enums.dart';

/// One focus session (CONTRACTS §3 `focus_sessions`).
class FocusSessions extends Table {
  /// UUID generated in Dart; also crosses the platform channel as the native
  /// session id (CONTRACTS §1).
  TextColumn get id => text()();

  TextColumn get status => textEnum<SessionStatus>()();
  DateTimeColumn get startTime => dateTime()();

  /// Set when the session reaches a terminal state.
  DateTimeColumn get endTime => dateTime().nullable()();

  IntColumn get plannedMin => integer()();

  /// Actual focused minutes; set on terminal transition.
  IntColumn get actualMin => integer().nullable()();

  TextColumn get taskAnchor =>
      text().withLength(max: FokusConstants.taskAnchorMaxChars).nullable()();

  BoolColumn get strictMode => boolean().withDefault(const Constant(false))();

  /// Only set when [status] == completed.
  TextColumn get completionReason =>
      textEnum<CompletionReason>().nullable()();

  /// Logged on every early-exit attempt (CONTRACTS §2).
  TextColumn get exitReason => textEnum<ExitReason>().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Apps the user blocks during sessions (CONTRACTS §3 `blocked_apps`).
class BlockedApps extends Table {
  TextColumn get packageName => text()();
  TextColumn get appName => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {packageName};
}

/// Always-available apps — never blockable, excluded from the picker
/// (CONTRACTS §3 `allowlisted_apps`, D-011).
class AllowlistedApps extends Table {
  TextColumn get packageName => text()();
  TextColumn get appName => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {packageName};
}

// FK columns use customConstraint instead of `.references()`: drift_dev ≤2.31
// with analyzer ≥10 parses the bare class name as a TypeLiteral, silently
// dropping the REFERENCES clause from the DDL (fixed upstream in 2.34).
// customConstraint replaces the generated NOT NULL, so it is restated.

/// Every intercept of a blocked app (CONTRACTS §3 `distraction_attempts`).
class DistractionAttempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId =>
      text().customConstraint('NOT NULL REFERENCES focus_sessions (id)')();
  TextColumn get packageName => text()();
  DateTimeColumn get ts => dateTime()();
  BoolColumn get recoveryInvoked =>
      boolean().withDefault(const Constant(false))();
}

/// Recovery module invocations — the product hypothesis data
/// (CONTRACTS §3 `recovery_events`; fokus-specs §3.3).
class RecoveryEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId =>
      text().customConstraint('NOT NULL REFERENCES focus_sessions (id)')();
  TextColumn get type => textEnum<RecoveryType>()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Null while the module is in progress.
  TextColumn get result => textEnum<RecoveryResult>().nullable()();
}

/// Singleton row (id always 1) — CONTRACTS §3 `streak_summary`.
/// The singleton invariant is enforced by a table-level CHECK (see
/// [customConstraints]) — a column-level `check(id.equals(1))` would be a
/// recursive getter (analyzer: recursive_getters).
class StreakSummary extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get currentDays => integer().withDefault(const Constant(0))();
  IntColumn get longestDays => integer().withDefault(const Constant(0))();

  /// Local calendar day (stored as midnight) of the last streak-qualifying
  /// session; null before the first one.
  DateTimeColumn get lastFocusDate => dateTime().nullable()();

  IntColumn get tokensAvailable => integer().withDefault(const Constant(0))();
  IntColumn get tokensLifetime => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

// ── Phase 2 tables (schema shipped now to avoid migrations; repositories
//    arrive with their features) ─────────────────────────────────────────

/// Named session configuration bundle (CONTRACTS §3 `presets`).
class Presets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get durationMin => integer()();
  BoolColumn get strictMode => boolean().withDefault(const Constant(false))();
  BoolColumn get recoveryEnabled =>
      boolean().withDefault(const Constant(true))();

  /// JSON-encoded list of blocked package names.
  TextColumn get blockedAppIds => text()();
}

/// Recurring auto-start schedule for a preset (CONTRACTS §3 `schedules`).
class Schedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get presetId =>
      integer().customConstraint('NOT NULL REFERENCES presets (id)')();

  /// JSON-encoded list of ISO weekday ints (1 = Monday … 7 = Sunday).
  TextColumn get daysOfWeek => text()();

  /// Local wall-clock start time, "HH:mm".
  TextColumn get startLocalTime => text()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

/// Unlocked achievements (CONTRACTS §3 `achievements`). Unlock once.
class Achievements extends Table {
  TextColumn get code => text()();
  DateTimeColumn get unlockedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {code};
}

/// Post-session micro-feedback (CONTRACTS §3 `feedback_entries`).
@DataClassName('FeedbackEntry')
class FeedbackEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  IntColumn get rating => integer().nullable()();

  /// SQL column `text` per contract; Dart getter renamed to avoid clashing
  /// with the `Table.text()` builder.
  TextColumn get feedbackText => text().nullable().named('text')();
  TextColumn get contextJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Locally generated rule-based suggestions (CONTRACTS §3 `ai_insights`).
class AiInsights extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get contentJson => text()();
  DateTimeColumn get generatedAt => dateTime()();
  DateTimeColumn get shownAt => dateTime().nullable()();
  BoolColumn get actedOn => boolean().withDefault(const Constant(false))();
}
