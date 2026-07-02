# FOKUS release shrinking rules (F-21). The Flutter Gradle plugin supplies
# the Flutter-engine keep rules; these protect what R8 cannot see.

# The blocking core is wired via the manifest / system callbacks, not code
# references R8 can trace — a stripped or renamed service is a silent
# 1-star blocker.
-keep class ch.hoffely.fokus.blocking.FokusAccessibilityService { *; }
-keep class ch.hoffely.fokus.blocking.SessionForegroundService { *; }
-keep class ch.hoffely.fokus.blocking.BootReceiver { *; }
-keep class ch.hoffely.fokus.blocking.ScheduleSkipReceiver { *; }
-keep class ch.hoffely.fokus.blocking.InterceptActivity { *; }

# WorkManager instantiates workers reflectively by class name.
-keep class ch.hoffely.fokus.blocking.ScheduleStartWorker { *; }
-keep class ch.hoffely.fokus.blocking.ScheduleReminderWorker { *; }

# drift/sqlite3: the bundled native library is loaded via JNI lookups.
-keep class org.sqlite.** { *; }
-keep class com.simolus.sqlite3_flutter_libs.** { *; }

# Kotlin metadata used by the channel handler's argument reflection is safe
# to strip; nothing else reflects in this app (no network, no serializers).
