import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/enums.dart';
import 'package:fokus/features/exit/application/exit_flow.dart';

/// The fokus-specs §3.4 decision table, exhaustively. Strict mode may only
/// ever change the needApp outcome — everything else identical is the
/// "emergency is never gated" guarantee in table form.
void main() {
  test('non-strict outcomes', () {
    expect(
      ExitFlow.outcomeFor(ExitReason.finishedTask, strictMode: false),
      ExitOutcome.completeAsFinished,
    );
    expect(
      ExitFlow.outcomeFor(ExitReason.emergency, strictMode: false),
      ExitOutcome.exitNow,
    );
    expect(
      ExitFlow.outcomeFor(ExitReason.stuck, strictMode: false),
      ExitOutcome.recoveryHub,
    );
    expect(
      ExitFlow.outcomeFor(ExitReason.tired, strictMode: false),
      ExitOutcome.recoveryBreathe,
    );
    expect(
      ExitFlow.outcomeFor(ExitReason.needApp, strictMode: false),
      ExitOutcome.pickPassApp,
    );
  });

  test('strict mode changes needApp only (F-08 done-criterion)', () {
    expect(
      ExitFlow.outcomeFor(ExitReason.needApp, strictMode: true),
      ExitOutcome.strictDenied,
    );
    for (final reason in ExitReason.values) {
      if (reason == ExitReason.needApp) continue;
      expect(
        ExitFlow.outcomeFor(reason, strictMode: true),
        ExitFlow.outcomeFor(reason, strictMode: false),
        reason: '$reason must be identical in strict mode',
      );
    }
  });
}
