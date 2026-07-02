import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/app.dart';
import 'package:fokus/core/blocking/providers.dart';
import 'package:fokus/core/data/enums.dart';
import 'package:fokus/core/session/session_controller.dart';
import 'package:integration_test/integration_test.dart';

/// M2 emulator-pass driver (D-012): arms a REAL session through the real
/// channel stack (Dart → BlockingChannelHandler → BlockedSetCache + FGS).
/// The start-config UI lands with F-11; until then this is the honest way to
/// start a session on-device. The session outlives this test on purpose —
/// blocking is native — so the M2 checklist (intercept latency, process kill,
/// reboot restore) is verified from adb afterwards.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('arm a 30-min session blocking Chrome', (tester) async {
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FokusApp()),
    );
    // Bounded pumps — the live ticker means pumpAndSettle would never settle.
    await tester.pump(const Duration(seconds: 1));

    await container
        .read(blockingAdapterProvider)
        .setBlockedApps(['com.android.chrome']);

    await container.read(sessionControllerProvider.notifier).start(
          plannedMin: 30,
          taskAnchor: 'M2 emulator pass',
        );
    await tester.pump(const Duration(seconds: 1));

    expect(
      container.read(sessionControllerProvider).status,
      SessionStatus.active,
    );
  });
}
