import 'dart:convert';

import 'package:drift/drift.dart';

import '../database.dart';

/// Data access for `presets` + `schedules` (CONTRACTS §3, F-13). Pure
/// persistence — occurrence math and arming live natively (mechanism), the
/// sync policy in the presets feature.
class PresetRepository {
  PresetRepository(this._db);

  final FokusDatabase _db;

  // ---------------------------------------------------------------- presets

  Future<int> createPreset({
    required String name,
    required int durationMin,
    required bool strictMode,
    required bool recoveryEnabled,
    required List<String> blockedPackages,
  }) =>
      _db.into(_db.presets).insert(
            PresetsCompanion.insert(
              name: name,
              durationMin: durationMin,
              strictMode: Value(strictMode),
              recoveryEnabled: Value(recoveryEnabled),
              blockedAppIds: jsonEncode(blockedPackages),
            ),
          );

  Future<void> updatePreset(
    int id, {
    String? name,
    int? durationMin,
    bool? strictMode,
    bool? recoveryEnabled,
    List<String>? blockedPackages,
  }) async {
    final rows = await (_db.update(_db.presets)..where((p) => p.id.equals(id)))
        .write(PresetsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      durationMin:
          durationMin == null ? const Value.absent() : Value(durationMin),
      strictMode:
          strictMode == null ? const Value.absent() : Value(strictMode),
      recoveryEnabled: recoveryEnabled == null
          ? const Value.absent()
          : Value(recoveryEnabled),
      blockedAppIds: blockedPackages == null
          ? const Value.absent()
          : Value(jsonEncode(blockedPackages)),
    ));
    if (rows == 0) throw StateError('No preset with id $id');
  }

  /// Deletes the preset and its schedules (no FK cascade in the schema —
  /// explicit two-step, schedules first).
  Future<void> deletePreset(int id) async {
    await (_db.delete(_db.schedules)..where((s) => s.presetId.equals(id)))
        .go();
    await (_db.delete(_db.presets)..where((p) => p.id.equals(id))).go();
  }

  Future<List<Preset>> getPresets() => (_db.select(_db.presets)
        ..orderBy([(p) => OrderingTerm.asc(p.name)]))
      .get();

  Stream<List<Preset>> watchPresets() => (_db.select(_db.presets)
        ..orderBy([(p) => OrderingTerm.asc(p.name)]))
      .watch();

  static List<String> decodePackages(Preset preset) =>
      (jsonDecode(preset.blockedAppIds) as List).cast<String>();

  // -------------------------------------------------------------- schedules

  Future<int> createSchedule({
    required int presetId,
    required List<int> daysOfWeek,
    required String startLocalTime,
    bool enabled = true,
  }) =>
      _db.into(_db.schedules).insert(
            SchedulesCompanion.insert(
              presetId: presetId,
              daysOfWeek: jsonEncode(daysOfWeek),
              startLocalTime: startLocalTime,
              enabled: Value(enabled),
            ),
          );

  Future<void> updateSchedule(
    int id, {
    List<int>? daysOfWeek,
    String? startLocalTime,
    bool? enabled,
  }) async {
    final rows =
        await (_db.update(_db.schedules)..where((s) => s.id.equals(id)))
            .write(SchedulesCompanion(
      daysOfWeek: daysOfWeek == null
          ? const Value.absent()
          : Value(jsonEncode(daysOfWeek)),
      startLocalTime: startLocalTime == null
          ? const Value.absent()
          : Value(startLocalTime),
      enabled: enabled == null ? const Value.absent() : Value(enabled),
    ));
    if (rows == 0) throw StateError('No schedule with id $id');
  }

  Future<void> deleteSchedule(int id) =>
      (_db.delete(_db.schedules)..where((s) => s.id.equals(id))).go();

  Future<List<Schedule>> schedulesForPreset(int presetId) =>
      (_db.select(_db.schedules)..where((s) => s.presetId.equals(presetId)))
          .get();

  Future<List<Schedule>> enabledSchedules() =>
      (_db.select(_db.schedules)..where((s) => s.enabled.equals(true))).get();

  static List<int> decodeDays(Schedule schedule) =>
      (jsonDecode(schedule.daysOfWeek) as List).cast<int>();

  Future<Preset?> presetById(int id) =>
      (_db.select(_db.presets)..where((p) => p.id.equals(id)))
          .getSingleOrNull();
}
