import 'package:drift/drift.dart';

import '../database.dart';

/// Data access for `blocked_apps` and `allowlisted_apps`.
///
/// Invariant (D-011, fokus-specs §3.2): an app is never in both lists —
/// adding to one removes it from the other.
class AppListsRepository {
  AppListsRepository(this._db);

  final FokusDatabase _db;

  // ── Blocked apps ──────────────────────────────────────────────────────

  Future<List<BlockedApp>> getBlockedApps() =>
      (_db.select(_db.blockedApps)
            ..orderBy([(a) => OrderingTerm.asc(a.appName)]))
          .get();

  Stream<List<BlockedApp>> watchBlockedApps() =>
      (_db.select(_db.blockedApps)
            ..orderBy([(a) => OrderingTerm.asc(a.appName)]))
          .watch();

  /// Package names only — what gets pushed to the native blocked-set cache.
  Future<List<String>> getBlockedPackageNames() async =>
      (await getBlockedApps()).map((a) => a.packageName).toList();

  Future<void> addBlockedApp({
    required String packageName,
    required String appName,
    DateTime? addedAt,
  }) =>
      _db.transaction(() async {
        await (_db.delete(_db.allowlistedApps)
              ..where((a) => a.packageName.equals(packageName)))
            .go();
        await _db.into(_db.blockedApps).insert(
              BlockedAppsCompanion.insert(
                packageName: packageName,
                appName: appName,
                addedAt: addedAt ?? DateTime.now(),
              ),
              mode: InsertMode.insertOrReplace,
            );
      });

  Future<void> removeBlockedApp(String packageName) =>
      (_db.delete(_db.blockedApps)
            ..where((a) => a.packageName.equals(packageName)))
          .go();

  /// Replaces the entire blocked set atomically (app-picker "save").
  /// Allowlisted apps are excluded — allowlist wins (D-011).
  Future<void> replaceBlockedApps(
    List<({String packageName, String appName})> apps, {
    DateTime? addedAt,
  }) =>
      _db.transaction(() async {
        final allowlisted =
            (await getAllowlistedApps()).map((a) => a.packageName).toSet();
        await _db.delete(_db.blockedApps).go();
        for (final app in apps) {
          if (allowlisted.contains(app.packageName)) continue;
          await _db.into(_db.blockedApps).insert(
                BlockedAppsCompanion.insert(
                  packageName: app.packageName,
                  appName: app.appName,
                  addedAt: addedAt ?? DateTime.now(),
                ),
              );
        }
      });

  // ── Allowlisted apps (never blockable) ────────────────────────────────

  Future<List<AllowlistedApp>> getAllowlistedApps() =>
      (_db.select(_db.allowlistedApps)
            ..orderBy([(a) => OrderingTerm.asc(a.appName)]))
          .get();

  Stream<List<AllowlistedApp>> watchAllowlistedApps() =>
      (_db.select(_db.allowlistedApps)
            ..orderBy([(a) => OrderingTerm.asc(a.appName)]))
          .watch();

  Future<void> addAllowlistedApp({
    required String packageName,
    required String appName,
    DateTime? addedAt,
  }) =>
      _db.transaction(() async {
        await (_db.delete(_db.blockedApps)
              ..where((a) => a.packageName.equals(packageName)))
            .go();
        await _db.into(_db.allowlistedApps).insert(
              AllowlistedAppsCompanion.insert(
                packageName: packageName,
                appName: appName,
                addedAt: addedAt ?? DateTime.now(),
              ),
              mode: InsertMode.insertOrReplace,
            );
      });

  Future<void> removeAllowlistedApp(String packageName) =>
      (_db.delete(_db.allowlistedApps)
            ..where((a) => a.packageName.equals(packageName)))
          .go();
}
