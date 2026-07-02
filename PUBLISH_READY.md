# FOKUS — Publish-Ready Handoff

**Date:** 2026-07-02 · **Author:** worker session (Claude Code) · **Package:** `ch.hoffely.fokus`
· **Publisher:** Hoffely GmbH · **Toolchain:** Flutter 3.44.2 (Dart 3.12) · **Target:** Android
closed track (D-003 defers billing/iOS/Firebase).

This file is the single source of truth for "what's done" and "what only Prashant can do."

---

## 1. State of everything

**All build work is complete and CI-green.** Phase A (core loop) and Phase B (engagement) are
done; the release build is configured; store paperwork and graphics are drafted/staged.

### Milestones (docs/ROADMAP.md)
- **M1 It builds** ✓ · **M2 It blocks** ✓ · **M3 Core loop** ✓ · **M4 Retention** ✓ ·
  **M5 Engagement** ✓ · **M6 Store-ready** — *build-ready*, Prashant-only remainder below.

### Features (docs/TASKBOARD.md) — all `done`, CI-verified
- **F-01…F-06** scaffold, drift schema, Kotlin blocking core (AccessibilityService, FGS,
  BootReceiver, InterceptActivity), Dart session engine.
- **F-07** recovery (5 modules) · **F-08** exit flow (5 reasons, strict consequences, native
  5-min pass) · **F-09** streaks/tokens/complete screen/today stats · **F-10** onboarding +
  prominent disclosure · **F-11** home/config/active-session (sacred one-tap repeat) ·
  **F-12** settings/permissions-health/theme + **Plus Jakarta Sans bundled** · **F-22** D-013
  P1 fixes.
- **F-13** presets + WorkManager schedules · **F-14** stats dashboard + focus score (beta) ·
  **F-15** 8 achievements + badges · **F-16** micro-feedback (1-in-3) · **F-17** local
  rule-based suggestions (opt-in).

### Quality gates
- **CI:** green through run #20 (9da83e3); run #21 (a74d0ea, D-024 + release config) verify
  the current HEAD. Pipeline = analyze + 283 Dart tests + assembleDebug + Kotlin JVM tests.
- **Independent M4 review** (docs/reviews/M4-review.md): approve-with-fixes, 0 P0; both P1s
  fixed (D-021).
- **Device passes:** M2 emulator pass (docs/reviews/M2-emulator-pass.md) + M5 QA matrix
  (docs/reviews/M5-qa-matrix.md) — all buildable P0/P1 PASS on the AVD, incl. reboot, process
  kill, permission loss, and **schedule auto-start firing on time**.
- **Release build:** `flutter build appbundle --release` produces a clean 61 MB `.aab` with
  R8/shrink + proguard rules protecting the blocking core, drift, and WorkManager workers.

### Privacy posture (verified)
Zero network permission; no analytics SDK; all behavioral data local (drift). The independent
review confirmed no data leaves the device.

---

## 2. The exact Prashant-only remainder (nothing else blocks the closed track)

### Must-do before upload
1. **Play Console:** create the app under Hoffely GmbH as `ch.hoffely.fokus` (D-004).
2. **Keystore + Play App Signing:** generate the upload keystore (NEVER committed — repo is
   configured to read `android/key.properties`, which is gitignored). Create
   `android/key.properties` with `storeFile/storePassword/keyAlias/keyPassword`; the release
   build auto-picks it up. Enroll in Play App Signing.
3. **⚠ Verbatim disclosure approval (Play-policy-critical):** the in-app accessibility
   disclosure copy is a **marked `[PLACEHOLDER]`** in `lib/l10n/app_en.arb`/`app_de.arb`
   (`onbDisclosureBody`). Approve/replace the final wording, and make it **match** the
   AccessibilityService declaration text (highest rejection risk — see
   planning/F20_declarations_DRAFT.md). Then re-run `flutter gen-l10n`.
4. **Store listing copy approval:** review/approve planning/F20_store_listing_DRAFT.md (title,
   short + full description, EN + DE).
5. **Declarations (submit in Console):** planning/F20_declarations_DRAFT.md drafts the
   AccessibilityService form, QUERY_ALL_PACKAGES justification, FGS `specialUse` type, and the
   data-safety answers (truthful "no collection" for this offline scope).
6. **Privacy policy:** approve/legal-review planning/F20_privacy_policy_DRAFT.md, host on
   hoffely.ch (or the fokus domain), and paste the URL into the listing.
7. **Store graphics:** the 8 storyboard raw captures + handoff are in planning/
   (B03_store_graphics_handoff.md). Human/ux steps: export the 512 icon + 1024×500 feature
   graphic from `design/assets/*.svg`, compose caption bands in Figma, and recapture from a
   **release** build (drops the DEBUG banner) — ideally EN + DE, with dark-theme heroes.
8. **Content rating** questionnaire (utility → Everyone/PEGI 3) and **tester list** for the
   closed track.
9. **Rollout click.**

### Owed on real hardware (D-012 closed-track exit criteria — not blockers to *ship* to the
track, they're what the track *tests*)
- **QA row 9:** FGS survival against OEM battery killers (Samsung/Xiaomi/OnePlus).
- **<200 ms visible intercept render** on hardware (detection is instant; the emulator's
  software-GPU render was 212–384 ms warm).
- **Engine-dead scheduled-session cycle** end-to-end (D-024 fix is unit-verified; the
  native auto-start + blocking half was device-verified).

### Open product decisions (not code — recorded for you)
- D-A/D-B (priority-copy editorial), D-F (AI micro-coaching surface) — still open in D-011.
- Domain / waitlist / trademark for the website (B-02 is `review`).

---

## 3. Where things live

| What | Where |
|---|---|
| Orientation + rules | `CLAUDE.md` |
| Build spec (binding) | `fokus-specs.md` |
| Contracts (binding) | `docs/CONTRACTS.md` |
| Decisions (D-001…D-024) | `docs/DECISIONS.md` |
| Execution state | `docs/TASKBOARD.md` |
| Milestones | `docs/ROADMAP.md` |
| What/when | `docs/CHANGELOG.md` |
| Session MOM | `docs/DISCUSSIONS.md` |
| Reviews + device evidence | `docs/reviews/` (M2 pass, M4 review, M5 QA matrix, screenshots) |
| Store paperwork drafts | `planning/F20_*_DRAFT.md`, `planning/B03_store_graphics_handoff.md` (gitignored) |
| Release signing hook | `android/app/build.gradle.kts` (reads `android/key.properties`) |

---

## 4. One-command sanity check before you upload

```sh
flutter analyze && flutter test && flutter build appbundle --release
# .aab → build/app/outputs/bundle/release/app-release.aab
```

With `android/key.properties` present it is signed with your upload key; without it, it falls
back to the debug key (fine for a local smoke build, **rejected by Play** — create the key
first).

**Bottom line:** the app is code-complete, tested, reviewed, and release-configured. Everything
remaining requires your Play Console account, your keystore, your verbatim copy approvals, and
your rollout click.
