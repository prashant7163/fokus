import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/core/data/enums.dart';
import 'package:fokus/core/session/session_machine.dart';

/// Exhaustive check of the CONTRACTS §2 graph. The expectation table below
/// is written out independently from SessionMachine's own table (straight
/// from the contract text) so the test cannot become tautological — every
/// (state × trigger) pair is asserted, legal and illegal alike.
void main() {
  // (from, trigger) → to. Everything absent is illegal. Source: CONTRACTS §2.
  const legal = <(SessionStatus, SessionTrigger), SessionStatus>{
    // idle → pendingStart
    (SessionStatus.idle, SessionTrigger.startRequested):
        SessionStatus.pendingStart,
    // pendingStart → active
    (SessionStatus.pendingStart, SessionTrigger.startSucceeded):
        SessionStatus.active,
    // active ⇄ recoveryInProgress
    (SessionStatus.active, SessionTrigger.enterRecovery):
        SessionStatus.recoveryInProgress,
    (SessionStatus.recoveryInProgress, SessionTrigger.resumeRecovery):
        SessionStatus.active,
    // active → completed (timer end OR exit reason "finished task")
    (SessionStatus.active, SessionTrigger.timerCompleted):
        SessionStatus.completed,
    (SessionStatus.active, SessionTrigger.finishTask): SessionStatus.completed,
    // active → aborted
    (SessionStatus.active, SessionTrigger.abort): SessionStatus.aborted,
    // active → failedPermissions
    (SessionStatus.active, SessionTrigger.permissionLost):
        SessionStatus.failedPermissions,
  };

  group('every legal transition lands on the contract target', () {
    for (final entry in legal.entries) {
      final (from, trigger) = entry.key;
      test('$from --$trigger--> ${entry.value}', () {
        expect(SessionMachine.canApply(from, trigger), isTrue);
        expect(SessionMachine.apply(from, trigger), entry.value);
      });
    }
  });

  group('every illegal transition is rejected', () {
    for (final from in SessionStatus.values) {
      for (final trigger in SessionTrigger.values) {
        if (legal.containsKey((from, trigger))) continue;
        test('$from --$trigger--> throws', () {
          expect(SessionMachine.canApply(from, trigger), isFalse);
          expect(
            () => SessionMachine.apply(from, trigger),
            throwsA(isA<IllegalSessionTransition>()),
          );
        });
      }
    }
  });

  test('the contract has exactly 8 legal edges', () {
    final count = SessionMachine.transitionTable.values
        .fold<int>(0, (sum, states) => sum + states.length);
    expect(count, legal.length);
  });

  test('terminal states are completed, aborted, failedPermissions', () {
    expect(
      SessionMachine.terminal,
      {
        SessionStatus.completed,
        SessionStatus.aborted,
        SessionStatus.failedPermissions,
      },
    );
    // No trigger leaves a terminal state (covered pair-wise above, asserted
    // here as the invariant the controller relies on).
    for (final terminal in SessionMachine.terminal) {
      for (final trigger in SessionTrigger.values) {
        expect(SessionMachine.canApply(terminal, trigger), isFalse);
      }
    }
  });
}
