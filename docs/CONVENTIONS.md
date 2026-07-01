# FOKUS — Conventions

## Code

- Dart: `flutter_lints` defaults; no `dynamic` in public APIs; Riverpod providers named
  `xyzProvider`; one feature = one folder under `lib/features/` with `presentation/`,
  `application/` subfolders as needed.
- Kotlin: ktlint defaults; coroutines over callbacks; no business rules (durations, streak
  logic, copy text) in Kotlin — native layer is mechanism, Dart is policy.
- Strings: all user-facing copy in `lib/l10n/` ARB files from day 1 (DE + EN markets ahead).
- No TODOs without a taskboard ID: `// TODO(F-12): …`

## Git

- Branches: `feat/F-xx-short-name`, `fix/…`. `main` is always buildable.
- Commits: conventional-ish, imperative, reference task: `feat(F-07): recovery breathe module`.
- Never commit: `planning/`, keystores, `google-services.json`, `local.properties`.

## Testing bar

- Session state machine, streak calculator, recovery result handling: **unit-tested, no
  exceptions.** These carry the product.
- Native blocking service: instrumented smoke test where feasible; the rest is the on-device
  QA checklist (planning/, mirrored in TASKBOARD F-16).
- CI must run `flutter analyze` + `flutter test` + `./gradlew assembleDebug` green before merge.

## Agent/session workflow

1. Read `CLAUDE.md` → `docs/` in order.
2. Claim a task in `TASKBOARD.md` (set status + owner).
3. Work only within the task's stated file scope. Contract change needed? Stop, escalate.
4. Done = done-criteria met + tests green + taskboard updated in the same commit.
