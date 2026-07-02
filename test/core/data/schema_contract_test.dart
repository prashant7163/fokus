import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/database.dart';

import 'test_db.dart';

/// Guards the done-criterion "schema matches contract": SQL table and column
/// names below are copied verbatim from docs/CONTRACTS.md §3. If this test
/// needs editing, that is a CONTRACTS change → DECISIONS.md entry first.
void main() {
  late FokusDatabase db;

  setUp(() => db = testDb());
  tearDown(() => db.close());

  Future<Set<String>> tableNames() async {
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%'",
    ).get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  Future<Set<String>> columnsOf(String table) async {
    final rows =
        await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('all CONTRACTS §3 tables exist', () async {
    expect(
      await tableNames(),
      containsAll(<String>{
        'focus_sessions',
        'blocked_apps',
        'allowlisted_apps',
        'distraction_attempts',
        'recovery_events',
        'streak_summary',
        'presets',
        'schedules',
        'achievements',
        'feedback_entries',
        'ai_insights',
      }),
    );
  });

  test('focus_sessions columns match contract', () async {
    expect(
      await columnsOf('focus_sessions'),
      containsAll(<String>{
        'id',
        'status',
        'start_time',
        'end_time',
        'planned_min',
        'actual_min',
        'task_anchor',
        'strict_mode',
        'completion_reason',
        'exit_reason',
      }),
    );
  });

  test('streak_summary columns match contract', () async {
    expect(
      await columnsOf('streak_summary'),
      containsAll(<String>{
        'current_days',
        'longest_days',
        'last_focus_date',
        'tokens_available',
        'tokens_lifetime',
      }),
    );
  });

  test('recovery_events + distraction_attempts columns match contract',
      () async {
    expect(
      await columnsOf('recovery_events'),
      containsAll(
          <String>{'session_id', 'type', 'started_at', 'completed_at', 'result'}),
    );
    expect(
      await columnsOf('distraction_attempts'),
      containsAll(
          <String>{'session_id', 'package_name', 'ts', 'recovery_invoked'}),
    );
  });

  test('feedback_entries keeps contract column name `text`', () async {
    expect(await columnsOf('feedback_entries'), contains('text'));
  });
}
