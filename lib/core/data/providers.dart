import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'repositories/achievement_repository.dart';
import 'repositories/app_lists_repository.dart';
import 'repositories/distraction_repository.dart';
import 'repositories/recovery_repository.dart';
import 'repositories/session_repository.dart';
import 'repositories/streak_repository.dart';

/// The app-wide database. Tests override this with an in-memory executor.
final databaseProvider = Provider<FokusDatabase>((ref) {
  final db = FokusDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);

final appListsRepositoryProvider = Provider<AppListsRepository>(
  (ref) => AppListsRepository(ref.watch(databaseProvider)),
);

final distractionRepositoryProvider = Provider<DistractionRepository>(
  (ref) => DistractionRepository(ref.watch(databaseProvider)),
);

final recoveryRepositoryProvider = Provider<RecoveryRepository>(
  (ref) => RecoveryRepository(ref.watch(databaseProvider)),
);

final streakRepositoryProvider = Provider<StreakRepository>(
  (ref) => StreakRepository(ref.watch(databaseProvider)),
);

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepository(ref.watch(databaseProvider)),
);
