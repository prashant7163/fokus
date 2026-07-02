/// Domain enums persisted by the Drift schema — mirror docs/CONTRACTS.md §2/§3.
/// Values are stored by `name` (textEnum); renaming a value is a schema migration
/// AND a CONTRACTS change.
library;

/// Session states per CONTRACTS §2. `idle` and `pendingStart` are transient and
/// normally never persisted; they are included so the DB column can mirror the
/// state machine 1:1.
enum SessionStatus {
  idle,
  pendingStart,
  active,
  recoveryInProgress,
  completed,
  aborted,
  failedPermissions,
}

/// Why a session reached `completed` (CONTRACTS §2: timer end OR exit reason
/// "finished task"; fokus-specs §3.5: lock-break redemption completes distinctly).
enum CompletionReason { timerEnd, finishedTask, lockBreak }

/// Exit reasons, logged on every early-exit attempt (CONTRACTS §2).
enum ExitReason { finishedTask, emergency, stuck, tired, needApp }

/// Recovery module types (CONTRACTS §2).
enum RecoveryType { breathe, taskReset, stretch, water, changeDuration }

/// Outcome of a recovery invocation (CONTRACTS §2).
enum RecoveryResult { resumed, exited }
