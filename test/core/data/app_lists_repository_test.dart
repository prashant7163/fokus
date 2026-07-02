import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/database.dart';
import 'package:fokus/core/data/repositories/app_lists_repository.dart';

import 'test_db.dart';

void main() {
  late FokusDatabase db;
  late AppListsRepository repo;

  setUp(() {
    db = testDb();
    repo = AppListsRepository(db);
  });

  tearDown(() => db.close());

  test('add/remove blocked app round-trips', () async {
    await repo.addBlockedApp(
        packageName: 'com.instagram.android', appName: 'Instagram');

    final blocked = await repo.getBlockedApps();
    expect(blocked, hasLength(1));
    expect(blocked.single.packageName, 'com.instagram.android');
    expect(blocked.single.appName, 'Instagram');

    await repo.removeBlockedApp('com.instagram.android');
    expect(await repo.getBlockedApps(), isEmpty);
  });

  test('re-adding the same package is idempotent (pk = packageName)',
      () async {
    await repo.addBlockedApp(packageName: 'com.x', appName: 'X');
    await repo.addBlockedApp(packageName: 'com.x', appName: 'X (renamed)');

    final blocked = await repo.getBlockedApps();
    expect(blocked, hasLength(1));
    expect(blocked.single.appName, 'X (renamed)');
  });

  test('replaceBlockedApps swaps the whole set atomically', () async {
    await repo.addBlockedApp(packageName: 'com.old', appName: 'Old');

    await repo.replaceBlockedApps([
      (packageName: 'com.a', appName: 'A'),
      (packageName: 'com.b', appName: 'B'),
    ]);

    expect(await repo.getBlockedPackageNames(), ['com.a', 'com.b']);
  });

  test('allowlist add/remove round-trips', () async {
    await repo.addAllowlistedApp(
        packageName: 'com.spotify.music', appName: 'Spotify');
    expect((await repo.getAllowlistedApps()).single.appName, 'Spotify');

    await repo.removeAllowlistedApp('com.spotify.music');
    expect(await repo.getAllowlistedApps(), isEmpty);
  });

  test('an app can never be in both lists (D-011)', () async {
    await repo.addBlockedApp(packageName: 'com.maps', appName: 'Maps');
    await repo.addAllowlistedApp(packageName: 'com.maps', appName: 'Maps');

    expect(await repo.getBlockedApps(), isEmpty);
    expect((await repo.getAllowlistedApps()).single.packageName, 'com.maps');

    // And back the other way.
    await repo.addBlockedApp(packageName: 'com.maps', appName: 'Maps');
    expect(await repo.getAllowlistedApps(), isEmpty);
    expect((await repo.getBlockedApps()).single.packageName, 'com.maps');
  });

  test('replaceBlockedApps never overrides the allowlist (allowlist wins)',
      () async {
    await repo.addAllowlistedApp(packageName: 'com.nav', appName: 'Nav');

    await repo.replaceBlockedApps([
      (packageName: 'com.nav', appName: 'Nav'),
      (packageName: 'com.game', appName: 'Game'),
    ]);

    expect(await repo.getBlockedPackageNames(), ['com.game']);
    expect((await repo.getAllowlistedApps()).single.packageName, 'com.nav');
  });

  test('lists are sorted by app name', () async {
    await repo.addBlockedApp(packageName: 'com.z', appName: 'Zebra');
    await repo.addBlockedApp(packageName: 'com.a', appName: 'Antelope');

    final names = (await repo.getBlockedApps()).map((a) => a.appName);
    expect(names, ['Antelope', 'Zebra']);
  });
}
