# FOKUS — Product Blueprint Specs (Cleaned Full-Scope Reference)

**Version:** 1.1 (Living Document — cleaned pass over Blueprint v1.0)
**Last Updated:** July 2, 2026
**Status:** Pre-Development (Phase 1 in progress)
**Team Size:** 2–3 people
**Primary Platform:** Android (iOS to follow)

> **What this is.** The full-scope **vision reference** — all phases, all features, the long
> horizon. Cleaned so it is internally consistent with itself and aligned to the binding
> contracts where the two overlap.
>
> **What this is NOT.** This is not the build spec. Root `fokus-specs.md` is the binding
> current-build scope, and `docs/CONTRACTS.md` holds binding interfaces/enums/constants. Where
> this document touches current-scope items, **CONTRACTS wins** and this file has been aligned to
> it. If a future-phase item here ever contradicts a shipped contract, the contract governs.
>
> This file supersedes `planning/FOKUS_Product_Requirements_Blueprint.md` as the working vision
> reference. The original is retained unaltered for provenance.

---

## ⚠️ Inconsistency Register

Every finding from auditing Blueprint v1.0, its resolution here, and the rationale. Tag legend:

- **EDITORIAL** — an obvious, low-risk fix applied directly in this document. No product call.
- **DECISION-NEEDED** — Prashant must choose; a provisional resolution is applied and flagged.
- **CONTRACT-ALIGN** — current-scope item reconciled to `docs/CONTRACTS.md` (CONTRACTS wins).

### DECISION-NEEDED (Prashant must choose) — read these first

| # | Finding (blueprint refs) | Provisional resolution here | Why it needs a call |
|---|---|---|---|
| D-A | **"Premium Paywall + Billing" is marked P0 but sits in Phase 3** (§5 row 18). P0 is defined in §5 as "Ship is blocked without this," yet §15 explicitly ships the MVP with **no** premium. A P0 that the shippable MVP omits is a contradiction. | Reclassified to **P1** (Phase 3), since P0 must mean "MVP cannot ship without it." | Priority letters are also used as a marketing/investment signal. Prashant may instead want to redefine P0 as "blocked for *that phase's* release" rather than "blocked for MVP." That redefinition would touch several rows (see D-B), so it is a product call, not editorial. |
| D-B | **iOS engine + iOS parity marked P0 in Phase 4 rows** (§5 rows 21–22), inside a matrix whose stated purpose (§ intro, §23 footer) is "what to build now vs later" for MVP prioritization. Under the §5 definition, only Phase-1 items can truly be P0. Rows 18, 21, 22 break this. | Interpreted the P/priority column as **priority *within its own phase*** and added an explicit note to §5 saying so; left the letters as-is except D-A. | The whole priority scheme is either "global, MVP-anchored" or "per-phase." The matrix mixes both. Prashant should pick one convention; this ripples across rows 18/21/22 and how the team reads the whole table. |
| D-C | **Streak "qualifying session" definition differs across sections.** §6.6 and CONTRACTS say "≥1 completed session of **10+ min** in a local calendar day." §10 says "One qualifying focus session (**10+ minutes, completed successfully**) per calendar day" — the "successfully" qualifier is extra. Also §13 `FocusSession.status` has no explicit "completed ≥10min" concept; the streak rule lives outside the entity. | Standardized on the **CONTRACTS wording**: "≥ 1 **completed** session ≥ 10 min, local calendar day" everywhere in this doc. "Completed successfully" folded into "completed" (a session with status `completed`). | The wording is now consistent, but there is a real product question hiding here: does a **completed-via-lock-break** session (streak-preserving by design, §10) count toward *starting/extending* a streak, or only preserve an existing one? CONTRACTS/`fokus-specs` say lock-break keeps a streak intact but do not say it can *earn* a streak day from a session under 10 min of actual focus. Prashant should rule. |
| D-D | **Session states (§6.2) do not match the status enum (§13) or CONTRACTS §2.** §6.2 lists `idle → pending_start → active → blocked_attempt_detected → recovery_in_progress → paused → completed / aborted / failed_due_to_permissions`. §13 `status` enum is `scheduled / active / completed / aborted / failed`. CONTRACTS §2 is the authoritative machine: `idle → pendingStart → active ⇄ recoveryInProgress`, terminals `completed / aborted / failedPermissions`; **no `paused`, no `blocked_attempt_detected` as a persisted status, no `scheduled`.** | **Aligned to CONTRACTS §2.** In this doc: `blocked_attempt_detected` and `recovery_in_progress` are described as **transient UI/engine states** (recovery is `active ⇄ recoveryInProgress`), not persisted session statuses; the **persisted** `status` enum is `scheduled? / active / completed / aborted / failedPermissions`. Removed `paused` from the runtime machine. Flagged `scheduled` below. | Two open calls: (1) Is there a **`paused`** state at all? CONTRACTS says no; §6.2 says "if allowed." Confirm paused is out of scope for the state machine (a schedule-not-yet-started session is a different concept). (2) Does a **`scheduled`** status exist for schedule-created-but-not-started sessions? §13 has it; CONTRACTS' runtime machine does not list it because current scope hasn't built schedules. For full scope, `scheduled` likely belongs — Prashant/tech-lead confirm and it becomes a CONTRACTS change when schedules are built. |
| D-E | **iOS "always-on app" whitelisting (music/maps) is an open design question (§23 Q9) but blocking safety rules are asserted elsewhere.** `fokus-specs` §3.2 hard-codes never-blockable set (FOKUS, system UI, dialer, launcher, active calls) but says nothing about user-chosen always-allow (Spotify/Maps). §23 Q9 leaves it open. | Kept §23 Q9 open; added a cross-reference so the never-blockable set (safety) is clearly separated from user-configurable allowlist (Q9, unresolved). | Whether to auto-whitelist navigation/music, or expose a user allowlist, is a genuine UX/product decision with Play-policy and user-trust implications. Not editorial. |
| D-F | **AI Micro-Coaching recovery module (§6.4, Phase 2) is absent from the recovery-type enum in CONTRACTS §2**, which is current-scope-only (`breathe | taskReset | stretch | water | changeDuration`). §13 `RecoveryEvent.recovery_type` *does* list `ai_coaching`. | Kept `ai_coaching` in the **full-scope** recovery-type list in this doc (it is Phase 2 vision), and noted that adding it to the *binding* enum is a **future CONTRACTS change** when Phase 2 recovery lands — not a current-scope change. | Whether Phase-2 "AI Micro-Coaching" ships as a *recovery module* vs. a proactive suggestion (it overlaps heavily with §7 Smart Suggestions and the proactive intercept in §6.4) is a scoping call. Prashant should decide if it's a 6th recovery module or a suggestion surface. |

### EDITORIAL (obvious fixes, applied)

| # | Finding (blueprint refs) | Resolution |
|---|---|---|
| E-1 | **"Two Week Warrior" badge appears twice** — as a 14-day **streak milestone** reward (§10 streak table) *and* implied among achievements. On close read it is only in the streak table, but "Iron Will / Recovery Champion / Distraction Destroyer" etc. are streak-independent **achievements** (§10 achievements table) while "Two Week Warrior" is a **streak milestone badge**. The two badge systems overlap conceptually and a reader can't tell which system owns a 14-day badge. | Declared **one badge, one owner**: "Two Week Warrior" is a **streak-milestone** badge (§10 milestones), NOT a general achievement. Added an explicit note that milestone badges and achievement badges are two distinct systems, and cross-referenced them so no badge is defined in both. |
| E-2 | **"Social Focuser" achievement (§10, "Complete 5 group room sessions") is Phase-2-dependent but listed in an otherwise phase-agnostic achievements table.** The MVP-facing achievement set (`fokus-specs` §3.8) deliberately excludes it. | Kept Social Focuser in the **full-scope** achievements list but tagged it **[Phase 2 — requires Social Rooms]** and added a "MVP achievement subset" note pointing at the 8 shipping achievements. No achievement is now phase-ambiguous. |
| E-3 | **Recovery module naming drift.** §6.4 names modules "30-Second Breathe / Task Reset / Stand & Stretch / Water Break / Change Session Size / AI Micro-Coaching." §13 enum uses `breathe / stretch / task_reset / water / change_duration / ai_coaching`. CONTRACTS uses `breathe | taskReset | stretch | water | changeDuration`. "Change Session Size" vs "change_duration" vs "Shrink session" (`fokus-specs`) all name the same module. | Standardized **display names** and **enum keys** in one table (§6.4). Display: "Shrink Session" (matches `fokus-specs` current build); enum key `changeDuration`. "Water Break" display, key `water`. All five current modules now map 1:1 to the CONTRACTS enum; the 6th (`aiCoaching`) is marked Phase 2. |
| E-4 | **Recovery "Water Break" duration inconsistency.** §6.4 table says duration "45s" in the Duration column but the Description says "Guided 30-60 second reset." | Standardized to **45 s** (matches `fokus-specs` §3.3) and reworded the description to "guided ~45 s reset." |
| E-5 | **Completion/exit reason vocab split across §6.5, §13, CONTRACTS.** §13 `FocusSession` has both `completion_reason (finished / timer_ended / emergency / unlock_code / lock_break_used)` and `exit_reason (finished_task / emergency / stuck / tired / need_app)`. CONTRACTS §2 exit reasons: `finishedTask | emergency | stuck | tired | needApp`. The two "finished" spellings and the overlap between completion_reason and exit_reason are confusing. | Documented the **two-field model** explicitly: `exitReason` (why the user tried to leave, per CONTRACTS enum) and `completionReason` (how the session actually terminated). Aligned spellings to CONTRACTS (`finishedTask`, `needApp`). Noted `unlock_code` / `lock_break_used` completion reasons are **future scope** (not in current CONTRACTS, which lists aborted-via-unlock/lock-break as future). |
| E-6 | **Phase week-numbering overlap / ambiguity.** Phases are numbered in continuous week ranges (P1 W1–4, P2 W5–12, P3 W13–16, P4 W17–28, P5 W29–40) as if fully sequential, but §15 P4 says "apply for Apple entitlement immediately at week 17" while P2/P3 are still notionally the active build — implying parallelism the linear numbering hides. Also "Week 4 of Phase 1" (§19) is fine, but the continuous numbering makes "Week 17" ambiguous (absolute vs. phase-relative). | Kept the ranges but added a note: **week numbers are absolute, cumulative, and assume mostly-sequential execution**; where a phase kicks off external processes early (Apple entitlement) it is called out. No renumbering (that would be a planning decision), just disambiguated. |
| E-7 | **"AI-dependent" vs "offline-first" tension in AI positioning.** §7 says "the app works perfectly without AI" and §12 principle 1 is offline-first, but §7 Phase-5 conversational coach and §12 offline table mark AI suggestions "Partial" (advanced needs network). Not a contradiction, but the blueprint never states the **basic** AI tier is fully offline while only **advanced** coaching needs cloud. | Made the split explicit in §7 and the offline table: **Phase-2 Smart Suggestions = 100% on-device/offline** (local SQL, matches `fokus-specs` §3.10); only **Phase-5 conversational LLM coaching** requires network, and only when user-initiated. |
| E-8 | **`fokus.app/unlock` web portal is "Phase 2" in tech stack (§12) and roadmap week 11 (§15), but the feature-matrix row 15 says Phase 2 while the offline table & data model tie it to Firebase/Firestore** which the current DECISIONS (D-003) explicitly defer. No internal contradiction *within the blueprint*, but the blueprint's Phase-2 web portal collides with the project's "no Firebase until core loop validated" decision. | Left web-unlock in Phase 2 for the **vision**, but added a note that per project DECISIONS (D-003), all Firebase-dependent Phase-2 items (Social Rooms, Web Unlock, cloud feedback) are **gated behind core-loop validation** and are not part of the current local-only build. This is context, not a blueprint-internal fix. |
| E-9 | **Feedback storage says "Firebase or Canny" (§11) while privacy section (§18) says local-first and current scope is zero-network.** For MVP micro-feedback, `fokus-specs` §3.9 stores locally, no transmission. | Clarified: **post-session micro-feedback (MVP) is stored locally, never transmitted** (matches `fokus-specs`/CONTRACTS `feedback_entries`). Cloud feedback tools (Canny, Firebase) apply only to **Phase 2+ contextual/manual feedback**, which is deferred with the rest of the backend. |
| E-10 | **DistractionAttempt `action_taken` enum (§13: `blocked / temporary_unlock / exited`) vs CONTRACTS `distraction_attempts` table** which stores `recoveryInvoked` (bool) and no `action_taken` enum. | Noted the divergence: current-scope `distraction_attempts` follows CONTRACTS (packageName, ts, recoveryInvoked). The richer `action_taken` enum is a **future-scope** field (needed once temporary unlock / early-exit-from-intercept exist). Flagged as a future CONTRACTS extension, not applied now. |
| E-11 | **"Change Session Size" reduces to "10 more minutes" (§6.4) vs `fokus-specs` "reduce remaining time to 10 min ('finish small')".** §6.4 phrasing "Continue for just 10 more minutes?" reads as *adding* 10 min; `fokus-specs` means *shrinking remaining* to 10 min. | Standardized on **`fokus-specs` semantics**: "Shrink Session" reduces the *remaining* time to 10 minutes ("finish small"), it does not append 10 minutes. |
| E-12 | **Onboarding screen count: "3 screens + permissions" (§6.7, §16 Flow 1) omits the mandatory accessibility *disclosure* screen** that `fokus-specs` §3.11 and Play policy require **before** any settings redirect. The blueprint's onboarding lists value screens and a permission checklist but not the distinct pre-redirect disclosure screen. | Added the **prominent accessibility-service disclosure screen** to the onboarding flow in §6.7 and §16, positioned before the permission checklist, matching `fokus-specs` §3.11 (Play-policy-critical). |
| E-13 | **Durations offered: "15m / 30m / 1h / 2h / Custom" (§6.2) vs `fokus-specs`/CONTRACTS "15/30/60/120 min or custom 5–480 min."** Same set, but §6.2 omits the custom range bounds. | Added the custom range **5–480 min** to §6.2 to match CONTRACTS §4 and `fokus-specs` §3.1. Task-anchor max length (80 chars, `fokus-specs`) also added, since §6.3 omitted it. |
| E-14 | **Free-tier "Session length: Up to 2 hours" (§14) vs "Custom 5–480 min" (up to 8h) durations (§6.2).** The 480-min custom duration exceeds the free 2h cap; the blueprint never says the 8h option is premium-only. | Clarified in §14: the **120-min (2h) cap is a free-tier limit** (Phase 3, per CONTRACTS §4 "5 apps / 2h / 1 preset"); durations up to 480 min are a **premium** capability. Free users see up to 120 min; custom beyond 2h is gated. (Current build has no gating — noted.) |
| E-15 | **Achievement "Exam Hero" trigger wording: "Complete 20+ hours during a 7-day period" (§10) vs `fokus-specs` "20 h in 7 days."** Consistent, no change needed — verified. Listed for completeness. | No change (verified consistent). |
| E-16 | **§13 data model is account/cloud-shaped (User has email, auth_provider, subscription_tier; entities have user_id, platform)** while current scope (D-003, `fokus-specs`) is **accountless, single-user, local-only**. CONTRACTS §3 has no `users` table and no `user_id` FKs. | Noted the data model as **full-scope (multi-user/cloud) vision**; documented that current-build storage (CONTRACTS §3) is the **local-only subset**: no `users` table, no `user_id`, streak is a singleton row. The full-scope entities apply only once accounts/backend land (deferred). |
| E-17 | **`initiated_by` / `created_by` "supervisor" values appear in §13 `FocusSession`/`Schedule`** but supervised mode is Phase 5. Not wrong, just phase-tagging missing. | Tagged the supervisor-related enum values as **[Phase 5]** in §13 so current-scope readers don't treat `initiated_by: supervisor` as live. Current scope: `initiated_by ∈ {self, schedule}`. |
| E-18 | **Metrics "Recovery flow → resume rate" target (§20) uses the same metric named "recovery resume-rate" in `fokus-specs` §3.6 focus-score and CONTRACTS analytics (`recovery_resumed`/`recovery_exited`).** Consistent — verified; noted the naming is unified. | No change (verified). Standardized the display name to **"recovery resume-rate"** throughout this doc for one term. |

**Total distinct findings: 24** (6 DECISION-NEEDED, 18 EDITORIAL/CONTRACT-ALIGN; two of the editorial rows, E-15 & E-18, were verified-consistent no-ops).

---

## Table of Contents

1. [Product Vision](#1-product-vision)
2. [Competitive Landscape](#2-competitive-landscape)
3. [Target Users](#3-target-users)
4. [Core Problem & Positioning](#4-core-problem--positioning)
5. [Feature Matrix — Prioritized](#5-feature-matrix--prioritized)
6. [Detailed Feature Specifications](#6-detailed-feature-specifications)
7. [AI Integration Strategy](#7-ai-integration-strategy)
8. [Parental Control & Supervised Accounts](#8-parental-control--supervised-accounts)
9. [Web-Based Unlock Code System](#9-web-based-unlock-code-system)
10. [Reward & Streak System](#10-reward--streak-system)
11. [In-App Feedback Integration](#11-in-app-feedback-integration)
12. [Technical Architecture](#12-technical-architecture)
13. [Data Model](#13-data-model)
14. [Monetization](#14-monetization)
15. [Phased Roadmap](#15-phased-roadmap)
16. [User Flows](#16-user-flows)
17. [Screen Inventory](#17-screen-inventory)
18. [Security, Privacy & Compliance](#18-security-privacy--compliance)
19. [QA & Testing Strategy](#19-qa--testing-strategy)
20. [Metrics & Success Criteria](#20-metrics--success-criteria)
21. [Risk Register](#21-risk-register)
22. [Budget Estimate](#22-budget-estimate)
23. [Open Questions & Future Exploration](#23-open-questions--future-exploration)
24. [Changelog](#24-changelog)

---

## 1. Product Vision

**One-liner:** FOKUS is an AI-assisted focus companion that helps users block distractions, recover from attention breaks, and build lasting focus habits — starting with students and expanding to professionals and families.

**Evolution path:**

```
Phase 1          Phase 2-3           Phase 4-5            Long Term
App Blocker  →   Focus System    →   AI Attention Coach → Family Focus Platform
(block apps)     (recover, track,    (predict, suggest,   (parental controls,
                  social rooms)       personalize)         schools, teams)
```

**Mission:** Make it easier to stay focused than to get distracted.

**Core principles:**
- Compassionate, not punitive — help users recover, don't just lock them out
- AI-assisted, not AI-dependent — the app works without AI; AI makes it smarter
- Privacy-first — behavioral data stays local; sync is opt-in
- Offline-resilient — core blocking never depends on a network connection

---

## 2. Competitive Landscape

### Major Competitors (March 2026)

| App | Platform | Price | Strength | Weakness | AI? |
|-----|----------|-------|----------|----------|-----|
| **Freedom** | iOS, Android, macOS, Windows, Chrome | $40/yr | Cross-platform sync, strict Locked Mode | No recovery, no social, dated UI | No |
| **Opal** | iOS, Android, Desktop | $100/yr | Gamified focus scoring, premium feel, community | Expensive, iOS-centric | No |
| **Forest** | iOS, Android | $2 one-time + IAP | Fun tree metaphor, real tree planting partner | Soft blocking only (guilt-based), no real enforcement | No |
| **AppBlock** | Android, iOS | Free/Premium | Feature-rich on Android, strict mode | Utilitarian UX, weak brand | No |
| **Cold Turkey** | macOS, Windows | $39 one-time | Most aggressive blocking, impossible to bypass | Desktop only, no mobile | No |
| **Attentive** | iOS only (Android waitlist) | $36/yr | Science-backed practices, psychology modules, beautiful design, App of the Day (Apple) | iOS only, no AI, no social features, no parental controls | No |
| **OneSecond** | iOS | Free/Premium | Adds friction (breathing before opening app) | Not a real blocker, iOS only | No |
| **Zario** | iOS, Android | Free/Premium | First digital wellbeing app claiming AI for insights | Early stage, limited feature set | Partial |
| **Focus Bear** | macOS, Windows | Subscription | AI determines website relevance to focus goals | Desktop only, no mobile | Yes |
| **Reclaim.ai** | Web/Calendar | Subscription | AI auto-schedules focus time on calendar | Not a blocker, works at calendar level only | Yes |

### Key insight: Attentive as a benchmark

Attentive is the closest competitor to FOKUS's philosophy — it treats digital wellbeing as a behavioral problem, not just a technical one. Its science-based "practices" (psychology modules users complete) are similar in spirit to FOKUS's Recovery System. Where Attentive falls short: it's iOS-only, has no social features, no AI, no parental controls, and no cross-platform strategy. FOKUS can learn from Attentive's strengths (beautiful design, psychology-grounded approach) while building what it lacks (Android, AI, social rooms, parental oversight).

### FOKUS Differentiators — Why Users Choose Us

| Differentiator | What It Is | Who Has It? |
|---------------|-----------|-------------|
| **Recovery System** | When users are tempted, guide them through breathing, task resets, micro-breaks instead of dead-end blocking | Nobody (Attentive has psychology modules but not in-flow recovery) |
| **AI Attention Coach** | Learns usage patterns, predicts distraction windows, suggests optimal focus times, personalizes recovery | Nobody does this as part of an app blocker |
| **Web-Based Unlock Code** | To unblock early, users must log into fokus web portal on another device and generate a time-limited code — maximum friction | Cold Turkey has something similar (desktop); nobody on mobile |
| **Social Focus Rooms** | Real-time group focus sessions with shared timer, participant status, leave alerts | Forest has basic co-planting; nobody has full rooms |
| **Parental/Supervisor Mode** | Parents link up to 10 accounts, control app access schedules, with child consent and transparency | Dedicated parental control apps exist, but no focus app combines self-use + supervised mode |
| **Streak Rewards with Lock Breaks** | Completing streaks earns "lock break" tokens redeemable for skipping a future block | Nobody — gamification reward is typically cosmetic only |
| **Student-first positioning** | Exam modes, university partnerships, student pricing, campus ambassadors | Nobody targets students specifically |

---

## 3. Target Users

### Primary: Self-motivated individuals

| Segment | Age | Key Need | Willingness to Pay |
|---------|-----|----------|-------------------|
| **University students** | 17–25 | Block social media during study/exams | Low (freemium, student pricing) |
| **Developers / knowledge workers** | 22–40 | Deep work blocks, minimize context switching | Medium-High |
| **Remote workers / freelancers** | 25–45 | Structure for unstructured days | Medium |
| **People reducing phone addiction** | 16–50 | Daily screen time reduction | Medium |

### Secondary: Supervised users

| Segment | Key Need | Decision Maker |
|---------|----------|---------------|
| **Children (10–17)** | Parents want to limit social media / gaming | Parent |
| **School students** | Teachers want focus during class hours | Teacher/School |
| **Corporate teams** | Companies want deep work culture | Team lead / IT admin |

### Geographic priority

1. **Launch:** Switzerland (home market, DACH region)
2. **Expand:** Germany, Austria → English-speaking markets (US, UK, AU)
3. **Long term:** Global

---

## 4. Core Problem & Positioning

### The problem

Smartphones create dopamine loops that destroy focus. Current solutions fail because they:
- Are easy to bypass (just uninstall the app or restart the phone)
- Only block — they don't help users recover when focus breaks
- Lack behavioral reinforcement (no habit formation)
- Feel punitive rather than supportive
- Don't learn or adapt to user patterns

### FOKUS positioning

**Tagline:** "Protect your attention."

**Positioning statement:** FOKUS is the first AI-assisted focus app that doesn't just block distractions — it helps you recover from them, learn your patterns, and build lasting attention habits. For students and professionals who want to reclaim their screen time without white-knuckling through it.

**Category:** Digital Wellbeing / AI-Assisted Productivity / Attention Management

---

## 5. Feature Matrix — Prioritized

### Priority definitions

- **P0 (Must-have):** Ship of the **MVP (Phase 1)** is blocked without this. Only Phase-1 items can be P0 under this definition.
- **P1 (Should-have):** Significant value **within its phase**; include if time permits.
- **P2 (Nice-to-have):** Valuable but can defer.
- **P3 (Future):** Validated later with user data.

> **[DECISION-NEEDED D-B]** The priority column below is read as **priority *within a feature's own phase*** (a Phase-3 P1 means "should-have for the Phase-3 release"), because a strict "P0 = MVP-blocking" reading makes P0 impossible for any Phase 2+ row. Prashant should confirm this convention or pick a global one; the ⚠️-tagged rows below are where the two readings diverge.

### Complete feature matrix

| # | Feature | Priority | Phase | Feasibility | Market Demand | Differentiator? |
|---|---------|----------|-------|-------------|--------------|----------------|
| 1 | App Blocking Engine (Android) | P0 | 1 | High | Proven | Table stakes |
| 2 | Focus Session Timer | P0 | 1 | High | Proven | Table stakes |
| 3 | Task Anchor | P0 | 1 | High | Medium | Mild (Attentive has similar) |
| 4 | Recovery System | P0 | 1 | High | Unmet need | **Strong** |
| 5 | Structured Exit Flow | P0 | 1 | High | Unmet need | **Strong** |
| 6 | Daily Streaks | P0 | 1 | High | Proven | Table stakes |
| 7 | Basic Stats (today view) | P0 | 1 | High | Proven | Table stakes |
| 8 | Onboarding + Permissions | P0 | 1 | High | Required | — |
| 9 | Focus Score | P1 | 2 | High | Medium | Mild (Opal has similar) |
| 10 | Focus Presets | P1 | 2 | High | High | Mild |
| 11 | Smart Scheduling | P1 | 2 | High | High | Mild |
| 12 | Social Focus Rooms | P1 | 2 | Medium | Medium | **Strong** |
| 13 | Achievements / Badges | P1 | 2 | High | Proven | Table stakes |
| 14 | Stats Dashboard (day/week/month) | P1 | 2 | High | High | Table stakes |
| 15 | Web-Based Unlock Code | P1 | 2 | Medium | Unmet need | **Strong** |
| 16 | In-App Feedback System | P1 | 2 | High | High | Mild |
| 17 | AI Smart Suggestions (basic) | P1 | 2 | Medium | High | **Strong** |
| 18 | Premium Paywall + Billing | ⚠️ **P1** *(was P0; see D-A)* | 3 | High | Required | — |
| 19 | Streak Reward: Lock Breaks | P2 | 3 | High | Unmet need | **Strong** |
| 20 | Gamification (trees/forest) | P2 | 3 | Medium | Proven (Forest) | Mild |
| 21 | App Blocking Engine (iOS) | ⚠️ P0 *(phase-relative; see D-B)* | 4 | Medium | Proven | Table stakes |
| 22 | iOS full feature parity | ⚠️ P0 *(phase-relative; see D-B)* | 4 | Medium | Required | — |
| 23 | Parental Control Mode | P1 | 5 | Medium | High | **Strong** |
| 24 | AI Attention Coach (advanced) | P1 | 5 | Medium-Low | High | **Strong** |
| 25 | Financial Commitment Stakes | P2 | 5 | Low (legal) | Medium | **Strong** |
| 26 | Cross-Device Sync | P2 | 5 | Medium | High | Mild (Freedom has it) |
| 27 | AI Behavior Modeling | P3 | 6+ | Low | Unknown | **Strong** |
| 28 | School/Classroom Mode | P3 | 6+ | Medium | Medium | **Strong** |
| 29 | Corporate/Team Mode | P3 | 6+ | Medium | Medium | Mild |
| 30 | Ambient Sound / Music | P3 | 6+ | High | Medium | Mild |

> **Note (Lock Breaks phasing):** Row 19 places lock-break *rewards* in Phase 3 (bundled with monetization/gamification build). The **streak → token earning mechanic** is defined in §10 and is part of the retention loop; per project scope (`fokus-specs` §3.5) the token earn/redeem loop is in the current local-only build even though the blueprint's Phase-3 row groups its *UI polish* with monetization. No blueprint-internal contradiction; noted for clarity.

---

## 6. Detailed Feature Specifications

### 6.1 App Blocking Engine

**Function:** Prevent access to selected apps during active focus sessions.

**Android implementation:**
- AccessibilityService monitors foreground app transitions
- When a blocked app is detected, immediately launch intercept activity (< 200 ms, per NFR)
- Foreground service maintains session state resiliently
- UsageStatsManager provides supplementary detection
- Boot receiver restores active sessions after device restart

**Never-blockable set (safety — always enforced):** FOKUS itself, system UI, phone/dialer, and the default launcher are never blockable; currently ringing/active calls are never intercepted. (Per `fokus-specs` §3.2.) This is distinct from a user-configurable **always-allow list** for utility apps like music/navigation — see **§23 Q9 (open)** and **[DECISION-NEEDED D-E]**.

**iOS implementation (Phase 4):**
- FamilyControls framework for user authorization
- ManagedSettings applies shields to selected apps
- DeviceActivity monitors scheduled intervals
- "Shielded apps" model (different UX from Android overlay model)

**Blocking intercept screen elements:**
- App icon + name ("Instagram is blocked right now" / "Instagram can wait")
- Time remaining in session
- Task anchor reminder
- Primary CTA: "Return to Focus"
- Secondary CTA: "I'm stuck" → triggers Recovery Flow
- Tertiary: "Emergency Exit" (de-emphasized)
- Proactive recovery surfacing: on repeated attempts (≥ 3 in 5 min) the recovery suggestion appears proactively on the intercept screen (per `fokus-specs` §3.2)

**UX principle:** The intercept screen should feel calm and redirecting, not punitive.

### 6.2 Focus Sessions

**Function:** User starts a timed session where selected apps are blocked.

**Session parameters:**
- Apps to block (select from installed apps)
- Duration: 15m / 30m / 1h / 2h / **Custom (5–480 min)** *(E-13: custom range added)*
- Task anchor text (what are you working on?) — free text, optional but prompted, **max 80 chars** *(E-13)*
- Strict mode toggle (disables early exit except emergency)
- Recovery support toggle

**Active session screen:**
- Large countdown timer (dominates visual hierarchy)
- Current task anchor (always visible)
- Apps being blocked (icon row)
- Progress ring / indicator
- Encouragement line (rotates)
- Emergency exit (hidden or de-emphasized)
- Mini stat: distractions blocked this session

**Session states — authoritative machine (aligned to CONTRACTS §2):** *(D-D)*

```
idle → pendingStart → active ⇄ recoveryInProgress
active → completed          (timer end OR exit reason "finishedTask")
active → aborted            (emergency; unlock-code / lock-break in future scope)
active → failedPermissions  (permission revoked mid-session)
```

- **Transient (non-persisted) states:** a blocked-app detection surfaces the intercept and, if the user enters recovery, moves the runtime to `recoveryInProgress` — these are engine/UI states, **not** persisted session statuses. There is **no `paused`** state in the current machine. *(D-D: "blocked_attempt_detected" and "recovery_in_progress" from Blueprint v1.0 §6.2 are transient; "paused" removed pending Prashant confirmation.)*
- **Persisted `status` enum:** `scheduled?` (schedule-created, not yet started — full scope only, see D-D) `/ active / completed / aborted / failedPermissions`.
- Timer is wall-clock anchored (`endEpochMs`), not tick-counted — survives process death and doze.

### 6.3 Task Anchor

**Purpose:** Keep users mentally connected to their work task throughout the session.

**Before session:** "What will you work on?" — free text field (max 80 chars, optional but prompted) with examples (Study Physics Ch. 3, Write quarterly report, Complete design mockups).

**During session:** Task appears on the active focus screen AND the blocking intercept screen. This is critical — when a user is redirected from Instagram, seeing "Study Physics Ch. 3" reminds them why they committed.

**After session:** Task is stored in session history for reflection.

### 6.4 Recovery System (KEY DIFFERENTIATOR)

**Purpose:** Help users survive the discomfort of distraction urges instead of escaping to apps. This is what transforms FOKUS from a blocker into a focus companion.

**Entry points:**
- Blocking intercept screen → "I'm stuck" button
- Exit attempt screen → reason = stuck / tired
- Proactive: repeated distraction attempts in a short window (≥ 3 in 5 min) surface recovery on the intercept screen (Phase 2+ for AI-personalized proactivity)

**Recovery modules — display name ↔ enum key ↔ phase (E-3, E-4, E-11):**

| Module (display) | Enum key | Description | Duration | Phase |
|--------|----------|-------------|----------|-------|
| **Breathe** | `breathe` | Animated breathing circle (inhale 4 s, hold 4 s, exhale 4 s; ≥ 2 cycles) | 30 s | 1 (MVP) |
| **Task Reset** | `taskReset` | "What's the next smallest step?" — text input, saved to session notes | ~15 s | 1 (MVP) |
| **Stand & Stretch** | `stretch` | Movement prompt with simple illustration, gentle timer | 45 s | 1 (MVP) |
| **Water Break** | `water` | Guided ~45 s reset with calm animation | 45 s | 1 (MVP) |
| **Shrink Session** | `changeDuration` | Reduce **remaining** time to 10 min ("finish small") — does not add time | instant | 1 (MVP) |
| **AI Micro-Coaching** | `aiCoaching` | Personalized nudge from patterns ("You usually push through — 20 min left") | ~10 s | 2 *(see D-F)* |
| **Guided Visualization** | *(TBD)* | 60 s audio-guided focus reset | 60 s | 3 |

> The five MVP modules map 1:1 to CONTRACTS §2 `Recovery types` (`breathe | taskReset | stretch | water | changeDuration`). **`aiCoaching`** appears in the §13 data model but is **not** in the current binding enum; adding it is a **future CONTRACTS change** when Phase-2 recovery lands. **[DECISION-NEEDED D-F]:** confirm AI Micro-Coaching ships as a recovery *module* vs. a proactive suggestion surface (it overlaps §7 Smart Suggestions).

**End state:** "Ready to continue?" → Resume Focus / End Session.

**Data captured (`RecoveryEvent`):** `recovery_type`, `started_at`, `completed_at`, `result (resumed | exited)`. This data is the product hypothesis — it feeds the AI coach to learn which recovery methods work best for each user.

### 6.5 Structured Exit Flow

**Trigger:** User attempts to end session before time is up.

**Prompt:** "Why are you leaving focus mode?" — exactly five options.

**Options (map to CONTRACTS `exitReason` enum: `finishedTask | emergency | stuck | tired | needApp`):** *(E-5)*
1. I finished my task → confirm + complete session (counts as success; `completionReason = finishedTask`)
2. Emergency → allow immediate exit (no penalty, no lecture)
3. I'm feeling stuck → open Recovery Flow
4. I'm too tired → open Recovery Flow
5. I need one app temporarily → temporary 5-min single-app pass, session timer keeps running (non-strict) **or** deny with kind copy (strict)

**Two-field model (E-5):**
- **`exitReason`** — *why the user tried to leave* (the five options above), logged on every early-exit attempt.
- **`completionReason`** — *how the session actually terminated*: `finishedTask | timerEnded | emergency` (current scope) plus `unlockCode | lockBreakUsed` (**future scope** — not in current CONTRACTS).

**Strict mode behavior:** Show consequences clearly before confirming an abort — streak impact, session marked incomplete, loss of lock-break progress. If lock-break tokens exist, offer redemption (§10) as a graceful alternative.

**Why this matters:** The exit reasons are product analytics gold. They tell you exactly why users quit and how to improve the experience. No competitor collects this data.

### 6.6 Streaks & Basic Stats

**Streak definition (aligned to CONTRACTS §3 / `fokus-specs` §3.5):** *(D-C)*
> A **streak day** counts when the user has **≥ 1 completed session of ≥ 10 min** in the local calendar day. Timezone changes use the device's current zone; a day never counts twice.

*(D-C open call: whether a completed-via-lock-break session, or a session under 10 min of actual focus that was ended via token, can **start/extend** a streak vs. only **preserve** one, is a product decision for Prashant. Current wording preserves an existing streak on token use per §10 but does not grant a new streak day from a sub-10-min session.)*

**Streak display:** Visual counter on home dashboard with fire progression (Day 1, Day 2… Day 7 🔥).

**Streak reset:** If the user misses a full calendar day with no qualifying session.

**Basic stats (MVP — today view only):**
- Focus time today
- Distractions blocked today
- Most distracting app today
- Current streak

### 6.7 Onboarding

**3 value screens → accessibility disclosure → permissions setup (E-12):**

| Screen | Headline | Subtext |
|--------|----------|---------|
| 1 | Take back control of your screen time | Block distracting apps and build real focus habits. |
| 2 | Stay focused when it matters | Exams, coding, deep work, reading, writing. |
| 3 | More than a blocker | Recover from distractions, build streaks, and train your attention. |

**Accessibility-service disclosure screen (E-12 — Play-policy-critical, per `fokus-specs` §3.11):**
A **prominent, standalone disclosure screen** shown **before any settings redirect**, with an explicit consent button and Play-policy-compliant wording (PM drafts, ships verbatim). This screen is mandatory and distinct from the permission checklist below.

**Permissions setup (Android) — checklist after disclosure:**
- Accessibility Service — "Needed to detect when you open a blocked app"
- Usage Access — "Needed to know which app is currently active"
- Notification permission — "To show your focus timer and remind you of sessions"
- Battery optimization exemption — "So your focus session doesn't get interrupted"

Each permission shows: title, one-line explanation, status badge (Granted / Not Granted), Enable button.

**Edge state:** "I'll do this later" → **limited mode** (timers work; blocking clearly labeled inactive). Permission health surfaces on home + settings whenever degraded.

---

## 7. AI Integration Strategy

### Philosophy

"AI-assisted, not AI-dependent." The app works perfectly without AI. AI makes it progressively smarter. Users should feel like FOKUS learns them over time — but it must never feel creepy or surveillance-like.

> **Offline split (E-7):** **Phase-2 Smart Suggestions are 100% on-device / offline** — time-of-day bucketing, rolling averages, completion-rate analysis over local SQL (matches `fokus-specs` §3.10). Only the **Phase-5 conversational LLM coach** requires a network, and only when the user initiates a coaching conversation. Basic pattern insights never leave the device.

### AI Integration by Phase

#### Phase 2: Smart Suggestions (Rule-based, on-device)

| Feature | How It Works | User Experience |
|---------|-------------|----------------|
| **Distraction prediction** | Analyze ≥ 2 weeks of local usage data to find patterns (e.g., "Instagram attempts spike at 8–9pm daily") | "You usually get distracted around 8pm. Start a 60-minute session?" |
| **Optimal session length** | Track completion rates by duration; suggest the length the user actually finishes | "Your best focus length seems to be about 55 minutes. Try that today?" |
| **Smart recovery selection** | Track which recovery modules lead to resumed vs. exited sessions; prioritize effective ones (min samples per module) | Recovery screen shows the method that works best for this user first |
| **Session summary insights** | After a session, highlight one behavioral insight | "You resisted 8 distractions today — 3 more than your average!" |

**Technical approach (Phase 2):** No ML models. Local SQL over session/distraction data — fully offline, opt-in via settings toggle. Max one suggestion per day; each shows its "why"; dismissible.

#### Phase 5: AI Attention Coach (On-device ML + Cloud LLM)

| Feature | How It Works | User Experience |
|---------|-------------|----------------|
| **Behavioral pattern modeling** | On-device ML model trained on the user's focus/distraction patterns | Weekly "Attention Report" with personalized insights |
| **Conversational coaching** | LLM-powered coach that can discuss focus struggles, suggest strategies, celebrate wins | "Hey FOKUS, why do I always lose focus after lunch?" → personalized response from the user's own data |
| **Proactive interventions** | Detect entry into a historically high-distraction window and proactively suggest a session | Push: "Based on your patterns, the next 2 hours are your most distraction-prone. Start a focus session?" |
| **Adaptive difficulty** | Gradually increase session lengths and reduce recovery frequency as the user improves | "You've been crushing 45-min sessions. Ready to try 60?" |
| **Cross-session learning** | Correlate focus performance with time/day/task/context | "You focus best on Tuesdays 9–11am on coding tasks" |

**Technical approach (Phase 5):**
- On-device: TensorFlow Lite / Core ML for pattern detection and prediction
- Cloud: LLM API (Claude or similar) for conversational coaching, called **only when the user initiates** a coaching session
- Privacy: all behavioral data stays on-device; only anonymized, aggregated patterns are sent for coaching conversations, user-controlled in settings

#### Phase 6+: AI Behavior Modeling (Research/Experimental)

- Predict burnout before it happens based on declining focus metrics
- Suggest schedule changes based on academic calendar or work deadlines
- Integrate with health data (sleep, exercise) to correlate with focus quality
- Personalized "focus curriculum" that evolves weekly

### AI Marketing Positioning

Use "AI-assisted" language from Phase 2 onward:
- App Store subtitle: "AI-Assisted Focus & App Blocker"
- Feature badge: "Smart Suggestions powered by AI" on session start screen
- Settings toggle: "Enable AI Insights" (opt-in, builds trust)

Even basic pattern analysis feels like AI to users and creates a differentiated experience — without over-promising.

---

## 8. Parental Control & Supervised Accounts

*(Phase 5 — requires accounts + backend; deferred per project DECISIONS D-003. Full-scope vision below.)*

### Overview

FOKUS Supervised Mode allows a parent (or teacher) to link child accounts and manage focus settings remotely. Premium feature (Phase 5) that extends FOKUS from a personal tool to a family/education platform.

### Account Model

```
Supervisor Account (Parent/Teacher)
├── Can link up to 10 Supervised Accounts
├── Supervised User 1 (Child)
├── Supervised User 2 (Child)
├── ...
└── Supervised User 10 (Child/Student)
```

### Linking Flow

1. Supervisor creates a FOKUS account and enables "Supervisor Mode" in settings
2. Supervisor sends an invite link (deep link or QR code) to the supervised user
3. Supervised user receives the invite in their FOKUS app
4. **Consent screen (critical):** Supervised user sees exactly what the supervisor can do:
   - View your focus session history
   - View your app blocking statistics
   - Set mandatory focus schedules
   - Restrict access to specific apps during set hours
   - Receive alerts when you attempt to bypass blocking
5. Supervised user must explicitly accept with a clear "I Agree" action
6. Link is established. Supervised user can revoke at any time (with notification to supervisor).

### Supervisor Capabilities

| Capability | Description | Consent Required? |
|-----------|-------------|-------------------|
| **View focus stats** | See supervised user's daily/weekly focus time, streak, distractions blocked | Yes (at link time) |
| **Set mandatory schedules** | Create focus schedules the supervised user cannot override (e.g., "No social media Mon–Fri 8am–3pm") | Yes (at link time) |
| **Restrict specific apps** | Block specific apps permanently or during set hours | Yes (at link time) |
| **Set daily app time limits** | Allow only X minutes of specific apps per day | Yes (at link time) |
| **Receive bypass alerts** | Get notified when supervised user attempts to access blocked apps | Yes (at link time) |
| **Approve unlock requests** | Supervised user requests temporary access; supervisor approves/denies from their app | Inline (per request) |
| **View detailed activity** | NO — supervisor cannot see in-app content, messages, or browsing | N/A — not supported |

### Transparency & Trust Design

**For the supervised user:**
- Persistent subtle indicator when supervised mode is active (small status-bar icon)
- Settings page clearly shows: who is supervising, what they can see, what they can control
- "Request Changes" button to ask supervisor to modify restrictions
- "Remove Supervisor" button always accessible (triggers notification to supervisor)

**For the supervisor:**
- Dashboard showing all linked accounts with summary stats
- Ability to create group schedules ("School hours" applies to all linked accounts)
- Cannot install/uninstall apps, read messages, track location, or access anything beyond FOKUS focus metrics

### School/Classroom Extension (Phase 6+)

- Teacher creates a "Classroom" group; students join via class code
- Teacher can activate "Exam Mode" for the entire class simultaneously
- After class hours, all restrictions automatically lift
- Requires school admin approval and parental consent for minors

### Privacy Safeguards

- Supervised users must be informed and consent — no covert monitoring
- Supervisors see focus metrics only, never content
- Supervised data stored separately with clear ownership
- GDPR/Swiss DPA compliant: supervised users (or guardians) can request full data deletion
- Under 16: parental/guardian consent legally required in Switzerland (nFADP)

---

## 9. Web-Based Unlock Code System

*(Phase 2 vision — requires Firebase/web portal; deferred per DECISIONS D-003 until core loop validated. E-8.)*

### Concept

To unblock apps before a session ends, the user must go through a deliberately inconvenient process: log into the FOKUS web portal on a separate device and generate a time-limited unlock code. Maximum friction without feeling like a prison.

### Why This Works

By the time a user finds another device, opens a browser, logs in, generates a code, and types it into their phone, the impulse has usually passed. The 2–3 minute process acts as a natural cooling period.

### Flow

```
Phone (FOKUS App)                    Other Device (Web Portal)
─────────────────                    ─────────────────────────
1. Tap "Emergency Exit"
2. See "Generate unlock
   code at fokus.app/unlock"
3. Wait for code input             4. Open fokus.app/unlock
                                    5. Log in with FOKUS account
                                    6. See active session details
                                    7. Confirm: "End session early?"
                                    8. 6-digit code generated
                                    9. Code shown (valid 5 minutes)
10. Enter 6-digit code
11. Session ends (logged as
    completionReason = unlockCode)
```

### Technical Design

**Web portal (fokus.app/unlock):**
- Simple responsive web page (no app needed)
- Firebase Auth (same account as mobile app)
- Shows active session details, time remaining, apps blocked, task anchor
- "Generate Unlock Code" button with confirmation dialog
- Cryptographic 6-digit code, stored in Firestore with 5-minute TTL
- Rate limited: max 3 codes per session, max 10 codes per day

**Mobile app:**
- "Emergency Exit" shows instructions to visit the web portal
- 6-digit numeric input; validates against Firestore in real time
- On valid code: session → `aborted`, `completionReason = unlockCode`
- On invalid/expired: error, suggest waiting or using recovery flow

### Configurable Strictness

| Mode | Unlock Code Available? | Notes |
|------|----------------------|-------|
| Normal | Yes | Users can also end session with the normal exit flow |
| Strict | Unlock code only | No local exit — web portal is the only way out |
| Maximum | No unlock available | Session runs to completion no matter what (user chose this) |

### Supervised Mode Integration

When a supervised user's session was set by a parent/teacher: unlock-code generation requires supervisor approval. Supervised user requests → supervisor push notification → approve/deny → code generated only on approval.

---

## 10. Reward & Streak System

### Streak Mechanics

**Definition (aligned to CONTRACTS / §6.6 — D-C):** A streak day counts with **≥ 1 completed session of ≥ 10 min** in a local calendar day. *(Wording standardized: previously "10+ minutes, completed successfully" — folded into "completed.")*

**Streak milestones (award Lock Break tokens + streak-milestone badges):**

| Streak | Reward | Type |
|--------|--------|------|
| 3 days | "Getting Started" badge | Cosmetic |
| 7 days | **1 Lock Break token** | Functional |
| 14 days | **2 Lock Break tokens** + "Two Week Warrior" badge | Functional + Cosmetic |
| 30 days | **3 Lock Break tokens** + "Monthly Master" badge | Functional + Cosmetic |
| 60 days | **5 Lock Break tokens** + "Unstoppable" badge | Functional + Cosmetic |
| 100 days | **10 Lock Break tokens** + special profile frame | Functional + Cosmetic |

> Token amounts match CONTRACTS §4 (`7d→1 · 14d→2 · 30d→3 · 60d→5 · 100d→10`).
> **Two badge systems (E-1):** the badges in this milestone table (e.g., **"Two Week Warrior"**, "Monthly Master") are **streak-milestone badges** — earned purely by streak length. They are a **separate system** from the **Achievements** below (which are behavior-triggered, streak-independent). **No badge is defined in both systems.** "Two Week Warrior" belongs to milestones only.

### Lock Break Tokens (Earned Unlock Credits)

**Concept:** Redeem one token to skip a single future focus session or end one session early — without it counting as a failure.

**Rules (match CONTRACTS §4):**
- 1 token = skip/end 1 session gracefully (status `completed-via-lockbreak`, logged distinctly)
- Using a token does NOT break your streak
- Tokens do not expire
- Tokens are **earned, never purchased** (keeps integrity)
- Maximum **3 redemptions per calendar week** (prevents hoarding/abuse)

**UX:** On exit, if tokens are available, a subtle option appears: "Use a Lock Break (you have N remaining)" alongside the normal exit flow.

**Why this works:** A psychological contract — you *earned* the right to a break. Users feel in control, not imprisoned. Also a retention mechanic: "I have 2 lock breaks saved — I should keep my streak to earn more."

### Achievements / Badges (Phase 2)

*(Behavior-triggered, streak-independent. Distinct from streak-milestone badges above — E-1.)*

| Achievement | Trigger | Icon Idea | Phase / Note |
|-------------|---------|-----------|--------------|
| First Session | Complete first focus session | Seedling | Ships in MVP subset |
| Early Bird | Start a session before 7am | Sunrise | Ships in MVP subset |
| Night Owl | Complete a session after 10pm | Moon | Ships in MVP subset |
| Distraction Destroyer | Block 100 distraction attempts | Shield | Ships in MVP subset |
| Recovery Champion | Successfully resume 10 times after recovery | Phoenix | Ships in MVP subset |
| Social Focuser | Complete 5 group room sessions | People | **[Phase 2 — requires Social Rooms]** *(E-2)* |
| Iron Will | Complete 10 strict-mode sessions | Lock | Ships in MVP subset |
| Exam Hero | Complete 20+ hours during a 7-day period | Graduation cap | Ships in MVP subset |
| Two Week Warrior | 14-day streak | — | **Streak-milestone badge, not an achievement (E-1)** — listed here only for cross-reference; owned by §10 milestones |

> **MVP achievement subset (per `fokus-specs` §3.8):** the eight shipping achievements are **First Session, Early Bird, Night Owl, Distraction Destroyer, Recovery Champion, Iron Will, Exam Hero, Two Week Warrior** (the last surfaced via the streak system). **Social Focuser is excluded from the MVP subset** because it depends on Phase-2 Social Rooms.

### Gamification (Phase 3 — Optional)

Visual growth metaphor tied to cumulative focus hours:
- 30 min → plant a seed · 2 hours → sapling · 10 hours → full tree · 50 hours → small forest · 200 hours → thriving ecosystem

Inspired by Forest; consider partnering with a real reforestation org (e.g., One Tree Planted) where premium users' focus hours translate to real trees planted.

---

## 11. In-App Feedback Integration

### Purpose

Capture user insights continuously to inform product decisions. Users who feel heard become advocates.

### Feedback Channels

#### 1. Post-Session Micro-Feedback (MVP — local only, E-9)

After a completed session, sampled **1 in 3** sessions:
- "How was this session?" → 😊 Great / 😐 Okay / 😔 Tough
- If 😔 Tough: follow-up "What made it hard?" → Too long / Got interrupted / Apps not blocked properly / Other

**Storage:** **Stored locally, never transmitted** (matches `fokus-specs` §3.9 and CONTRACTS `feedback_entries`). No network sink in current scope.

#### 2. Contextual Feedback Triggers (Phase 2 — deferred with backend)

| Trigger | Prompt |
|---------|--------|
| User exits 3 sessions in a row early | "We noticed you've been ending sessions early. What could we do better?" |
| User completes 7-day streak | "Congrats! What's your favorite feature so far?" |
| After first Social Room session | "How was your group focus experience? Any suggestions?" |
| After using Recovery for the first time | "Did the recovery exercise help? Which would you like to see more of?" |
| User hasn't opened app in 7 days | Re-engagement notification: "We miss you! What would bring you back?" |

#### 3. In-App Feedback Button (Phase 2)

- From Profile/Settings: "Send Feedback"
- Simple form: category (Bug, Feature Request, General) + text + optional screenshot
- Submitted to a lightweight support tool (e.g., Canny) **only in Phase 2+** — not in the local-only current build (E-9)

#### 4. Feature Voting Board (Phase 3)

- Public roadmap page (web) where users upvote requested features (Canny/Productboard/custom)
- Top-voted features inform Phase 5+ planning

### NPS Survey (Phase 3)

- Quarterly in-app NPS prompt: "How likely are you to recommend FOKUS?" (0–10)
- Segment by free vs. premium, streak length, session frequency
- Follow up with detractors (0–6) via email

---

## 12. Technical Architecture

### Architecture Principles

1. **Offline-first:** Core blocking, timer, and session state never depend on network availability
2. **Privacy-first:** All behavioral data processed locally by default; cloud sync is opt-in
3. **Native where it matters:** Blocking engine is 100% native (Kotlin / Swift); no cross-platform abstraction for OS-level services. **No blocking logic in Dart.**
4. **Modular:** Clean separation between blocking adapter, session engine, analytics, and UI layers

> **Current-build note (DECISIONS D-001/D-003):** the shipped app is **Flutter shell + native Kotlin blocking core**, **local-only, no Firebase, no accounts**. The Firebase/backend elements below are **full-scope vision**, gated behind core-loop validation. Where this section and CONTRACTS differ on current scope, CONTRACTS wins.

### Tech Stack

#### Android (Phase 1–3)

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Language | Kotlin (native core) + Dart/Flutter (UI shell) | Native blocking + cross-platform UI for future iOS reuse (D-001) |
| UI | Flutter (current build); Jetpack Compose referenced in original blueprint | *Current build uses Flutter shell per D-001; the original blueprint's Compose-only stack is superseded for this project.* |
| Architecture | MVVM + Clean Architecture | Testable, scalable, clear separation |
| Local Storage | Drift (SQLite) *(current build; blueprint said Room)* | Sessions, stats, app lists, settings — see CONTRACTS §3 |
| Background Work | Foreground Service + WorkManager | Session resilience, scheduled tasks |
| Blocking | AccessibilityService + UsageStatsManager | App detection and interception |
| Backend | **Firebase (deferred, Phase 2+)** | Auth, sync, push — only when core loop validated (D-003) |
| Analytics | **Local only in current scope; PostHog + Crashlytics deferred** | No analytics SDK in current build (`fokus-specs` NFR) |
| Payments | Google Play Billing v7+ (Phase 3) | In-app subscriptions |
| CI/CD | GitHub Actions | Automated builds, lint, tests |

> **Note:** The original blueprint's Android UI stack listed **Jetpack Compose** and storage **Room**. The project has since decided (DECISIONS D-001) on a **Flutter shell + native Kotlin** architecture with **Drift** storage. This doc records both but treats the DECISIONS/CONTRACTS choice as current truth.

#### iOS (Phase 4)

| Layer | Technology |
|-------|-----------|
| Language | Swift (native core) + Flutter (shared UI, per D-001 iOS-reuse rationale) |
| Blocking | FamilyControls + ManagedSettings + DeviceActivity |
| Backend | Firebase (shared with Android) |
| Payments | StoreKit 2 |
| Analytics | PostHog + Crashlytics (if adopted by then) |

#### Web Portal (Phase 2 — Unlock Code, deferred with backend)

| Layer | Technology |
|-------|-----------|
| Framework | Next.js or simple static site |
| Auth | Firebase Auth (shared) |
| Hosting | Firebase Hosting or Vercel |
| Database | Firestore (shared) |

### System Architecture Diagram (full-scope vision)

```
┌─────────────────────────────────────────────────────────┐
│                    FOKUS Mobile App                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐   │
│  │ UI Layer │  │ Session  │  │ Analytics │  │Rewards │   │
│  │(Flutter) │  │ Engine   │  │  Module   │  │ Engine │   │
│  └────┬─────┘  └────┬─────┘  └────┬──────┘  └───┬────┘   │
│  ┌────┴─────────────┴─────────────┴─────────────┴────┐   │
│  │            Local Database (Drift / SQLite)         │   │
│  └───────────────────────┬────────────────────────────┘  │
│  ┌───────────────────────┴────────────────────────────┐  │
│  │        Platform Blocking Adapter (Native)          │  │
│  │  Android: AccessibilityService + ForegroundSvc     │  │
│  │  iOS: FamilyControls + ManagedSettings             │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────┬───────────────────────────────┘
                           │ (sync when online — Phase 2+ only)
                           ▼
┌──────────────────────────────────────────────────────────┐
│              Firebase Backend (Phase 2+, deferred)        │
│   Auth · Firestore (rooms, sync) · FCM · Cloud Functions  │
└──────────────────────────┬───────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────────┐
│                    Web Portal (fokus.app)                 │
│  Unlock Code Generator  │  Parental Dashboard (Phase 5)   │
└──────────────────────────────────────────────────────────┘
```

### Blocking Adapter Interface

Current binding interface is CONTRACTS §1 (`fokus/blocking` MethodChannel, `fokus/events` EventChannel). The blueprint's conceptual adapter (below) is aligned to it:

```
BlockingAdapter:
  getPermissionStatus() → PermissionState
  requestPermission(kind)          // opens the right settings screen
  getInstalledApps() → List<InstalledApp>
  setBlockedApps(packageNames)
  startSession(config)             // id, endEpochMs, taskAnchor, strictMode
  stopSession(sessionId)
  events: Stream<BlockingEvent>     // distractionAttempt | interceptShown |
                                    // recoveryRequested | permissionLost | sessionRestored
  // createSchedule/removeSchedule → Phase 2 (schedules), not in current binding interface
```

### Offline Behavior

| Feature | Offline? | Details |
|---------|----------|---------|
| Active session timer | Yes | Runs locally (wall-clock anchored), no network |
| App blocking/detection | Yes | Native service, purely local |
| Session state persistence | Yes | Drift database |
| Recovery flow | Yes | All modules work offline |
| Streaks | Yes | Local date tracking |
| Basic stats | Yes | Local aggregation |
| **Smart Suggestions (Phase 2, basic)** | **Yes** | **100% on-device SQL (E-7)** |
| Social Rooms | No | Requires real-time backend (Phase 2+, deferred) |
| Unlock code | No | Requires web portal + Firestore (Phase 2+, deferred) |
| AI conversational coaching (Phase 5) | No | Cloud LLM, user-initiated only |
| Sync to cloud | No | Queued, syncs when online (Phase 2+) |

---

## 13. Data Model

> **Scope note (E-16, E-17):** This is the **full-scope, multi-user/cloud** data model. The **current local-only build** uses the subset in **CONTRACTS §3** — **no `users` table, no `user_id` FKs, streak is a singleton row**, and only the current-scope entities/columns exist. Supervisor-related enum values are **[Phase 5]**. Treat account/cloud fields below as future-scope until accounts/backend land.

### Core Entities

#### User *(full scope only — no such entity in current local build)*
- id (UUID) · email · auth_provider (Google/Apple/email) · timezone
- subscription_tier (free/premium/student) · supervisor_id (nullable) · preferences_json · created_at

#### BlockedApp
- id · user_id *(full scope)* · app_identifier (package/bundle) · platform · app_name · icon_ref · created_at
- **Current build (CONTRACTS `blocked_apps`):** packageName, appName, addedAt

#### FocusPreset (Phase 2)
- id · user_id *(full scope)* · name · default_duration_minutes · strict_mode · recovery_enabled · unlock_code_required · blocked_app_ids · created_at
- **Current build (CONTRACTS `presets`):** name, durationMin, strictMode, recoveryEnabled, blockedAppIds

#### FocusSession
- id · user_id *(full scope)* · preset_id (nullable)
- **status** — `scheduled` *(schedule-created, not started — full scope; see D-D)* `/ active / completed / aborted / failedPermissions` *(aligned to CONTRACTS §2; blueprint's `failed` → `failedPermissions`)*
- start_time · end_time · planned_duration_minutes · actual_duration_minutes · task_anchor (≤ 80 chars) · strict_mode · recovery_enabled
- **completion_reason** — `finishedTask / timerEnded / emergency` (current) + `unlockCode / lockBreakUsed` **(future scope)** *(E-5)*
- **exit_reason** (nullable) — `finishedTask / emergency / stuck / tired / needApp` *(CONTRACTS enum, E-5)*
- platform *(full scope)*
- **initiated_by** — `self / schedule` (current) + `supervisor` **[Phase 5]** *(E-17)*
- **Current build (CONTRACTS `focus_sessions`):** id, status, startTime, endTime, plannedMin, actualMin, taskAnchor, strictMode, completionReason, exitReason

#### DistractionAttempt
- id · session_id · app_identifier · timestamp · recovery_invoked (bool)
- **`action_taken` (`blocked / temporary_unlock / exited`) is future scope (E-10)** — needed once temporary-unlock / exit-from-intercept exist; not in current CONTRACTS.
- **Current build (CONTRACTS `distraction_attempts`):** sessionId, packageName, ts, recoveryInvoked

#### RecoveryEvent
- id · session_id · **recovery_type** (`breathe / stretch / taskReset / water / changeDuration` current; `aiCoaching` **[Phase 2, D-F]**) · started_at · completed_at · result (`resumed / exited`)
- **Current build (CONTRACTS `recovery_events`):** sessionId, type, startedAt, completedAt, result

#### UnlockCode (Phase 2 — deferred)
- id · session_id · user_id · code (6-digit) · generated_at · expires_at (+5 min) · used · approved_by (nullable — supervisor)

#### Schedule (Phase 2)
- id · user_id *(full scope)* · preset_id · days_of_week · start_local_time · (end_local_time or duration) · enabled · reminder_minutes_before · **created_by** (`self` current; `supervisor` **[Phase 5]**, E-17)
- **Current build (CONTRACTS `schedules`):** presetId, daysOfWeek, startLocalTime, enabled

#### StreakSummary
- **Current build (CONTRACTS `streak_summary`, singleton — no user_id):** currentDays, longestDays, lastFocusDate, tokensAvailable, tokensLifetime
- *(Full scope adds user_id when accounts exist.)*

#### Achievement (Phase 2)
- id · user_id *(full scope)* · achievement_code · unlocked_at
- **Current build (CONTRACTS `achievements`):** code, unlockedAt

#### FocusRoom / FocusRoomParticipant (Phase 2 — deferred with backend)
- **FocusRoom:** id · owner_user_id · name · status (waiting/active/completed) · start_time · duration_minutes · preset_snapshot_json · room_code · privacy (public/private)
- **FocusRoomParticipant:** id · room_id · user_id · joined_at · left_at (nullable) · status (joined/focusing/left_early/completed)

#### SupervisedLink (Phase 5)
- id · supervisor_user_id · supervised_user_id · status (pending/active/revoked) · permissions_granted_json · consent_given_at · revoked_at (nullable)

#### FeedbackEntry (Phase 2 for contextual/manual; MVP micro-feedback is local subset)
- id · user_id *(full scope)* · type (session_rating/contextual/manual/nps) · rating (nullable) · text (nullable) · context_json · created_at
- **Current build (CONTRACTS `feedback_entries`):** type, rating, text, contextJson, createdAt — **local only, never transmitted (E-9)**

#### AIInsight (Phase 2)
- id · user_id *(full scope)* · insight_type (distraction_prediction/optimal_duration/recovery_suggestion/weekly_report) · content_json · generated_at · shown_at (nullable) · acted_on
- **Current build (CONTRACTS `ai_insights`):** type, contentJson, generatedAt, shownAt, actedOn

---

## 14. Monetization

*(Freemium; billing is Phase 3 — reclassified P1, D-A. Not built in current local-only scope.)*

### Pricing Model: Freemium

| | Free | Premium | Family (Phase 5) |
|---|---|---|---|
| **Price** | CHF 0 | CHF 4.99/mo or CHF 29.99/yr | CHF 7.99/mo or CHF 49.99/yr |
| Apps per session | 5 | Unlimited | Unlimited |
| Session length | **Up to 2 hours (120 min)** | Unlimited (up to 480 min custom) | Unlimited |
| Streaks & basic stats | Yes | Yes | Yes |
| Recovery system | Yes | Yes | Yes |
| Focus Score | — | Yes | Yes |
| Presets | 1 | Unlimited | Unlimited |
| Schedules | — | Unlimited | Unlimited |
| Social Rooms | Join only | Create + Join | Create + Join |
| Stats dashboard | Today only | Full history + charts | Full history + charts |
| AI suggestions | — | Yes | Yes |
| Web unlock code | — | Yes | Yes |
| Lock Break tokens | Earn normally | Earn normally | Earn normally |
| Supervised accounts | — | — | Up to 10 |
| Supervisor dashboard | — | — | Yes |

> **Duration gating (E-14):** the **120-min (2h) session cap is the free-tier limit** (CONTRACTS §4 free-tier: 5 apps / 2h / 1 preset). Custom durations up to **480 min are premium-only**. Free users' duration picker tops out at 120 min. **No gating exists in the current build** — presets/durations are uncapped now (`fokus-specs` §3.7); caps arrive with Phase-3 monetization.

### Student Discount
- 50% off Premium with .edu or university email verification
- Consider free premium during exam periods (university partnerships)

### Paywall Triggers (natural upgrade moments)
- Saving more than 5 apps to block · creating a second preset · creating a schedule · accessing weekly/monthly stats · creating a Focus Room · enabling AI suggestions

### Revenue Model Considerations
- Lock Break tokens are **never purchasable** — earned only through streaks. Prevents "pay to not focus."
- Financial stakes (Phase 5) use a separate wallet system, not the subscription.

---

## 15. Phased Roadmap

> **Week numbering (E-6):** week numbers are **absolute and cumulative**, assuming mostly-sequential execution. Where a phase starts external processes early (e.g., Apple entitlement application), it is called out. "Week N" is absolute unless it says "Week N of Phase X."

### Phase 1: Android MVP (Weeks 1–4)

**Goal:** Ship a working focus app with blocking, recovery, and streaks on Android.

| Week | Focus | Key Deliverables |
|------|-------|-----------------|
| 1 | Core engine | Project setup, permission flow, AccessibilityService blocking, foreground service |
| 2 | Sessions + Recovery | Session timer, task anchor, blocking intercept, recovery flow (breathe, task reset, stretch, water, shrink session) |
| 3 | Retention + Polish | Streaks, basic today stats, onboarding (incl. accessibility disclosure), exit flow with reasons, session completion screen |
| 4 | Testing + Launch | OEM testing (Samsung, Pixel, Xiaomi, OnePlus), edge cases (reboot, battery kill, permission revoke), Play Store listing, closed beta |

**MVP ships with:** Blocking engine, focus sessions, task anchor, recovery system, structured exit flow, streaks, basic stats, onboarding.

**MVP does NOT ship with:** Presets, scheduling, social rooms, premium, AI, web portal, parental controls, gamification.

### Phase 2: Engagement + AI Foundations (Weeks 5–12)

> Firebase-dependent items (Social Rooms, Web Unlock, cloud feedback) are **gated behind core-loop validation** (DECISIONS D-003) and may slip past this window in practice.

| Week | Focus | Key Deliverables |
|------|-------|-----------------|
| 5–6 | Presets + Scheduling | Focus presets (Study, Deep Work, Sleep, Social Detox), recurring schedules, WorkManager |
| 7–8 | Social Focus Rooms | Firebase Auth, Firestore real-time rooms, room create/join, shared timer, participant status |
| 9–10 | Stats + Score + Achievements | Stats dashboard (day/week/month), Focus Score formula, achievement badge system |
| 11 | Web portal + Unlock Code | fokus.app/unlock, Firebase Auth, code generation, mobile validation |
| 12 | AI Smart Suggestions + Feedback | On-device distraction/length analysis, post-session micro-feedback (local), contextual triggers |

### Phase 3: Monetization (Weeks 13–16)

| Week | Focus | Key Deliverables |
|------|-------|-----------------|
| 13 | Paywall + Feature gating | Premium UI, feature flags (Remote Config) |
| 14 | Google Play Billing | Subscription flow, receipt validation, restore |
| 15 | Lock Break rewards + Gamification | Token earning, redemption in exit flow, visual growth metaphor |
| 16 | A/B testing + Student pricing | Paywall placement tests, .edu verification, conversion analytics |

### Phase 4: iOS (Weeks 17–28)

> **Apply for the Apple FamilyControls entitlement at the very start of Phase 4 (week 17)** — external approval with no SLA.

| Week | Focus |
|------|-------|
| 17–18 | SwiftUI/Flutter scaffold, onboarding, app picker |
| 19–21 | FamilyControls + ManagedSettings integration (entitlement applied week 17) |
| 22–23 | Session engine, recovery system, streaks, stats |
| 24–25 | Firebase integration (rooms, sync, push), web unlock support |
| 26–27 | StoreKit 2 premium, presets, scheduling |
| 28 | TestFlight beta, QA, App Store submission |

### Phase 5: Platform Expansion (Weeks 29–40)

| Week | Focus |
|------|-------|
| 29–32 | Parental Control / Supervised Mode (linking, consent, dashboard, mandatory schedules) |
| 33–36 | AI Attention Coach (on-device ML, conversational LLM, proactive interventions) |
| 37–38 | Financial Commitment Stakes (legal check, wallet, charity integration) |
| 39–40 | Cross-device sync, feature voting board, NPS survey |

### Phase 6+: Long-Term Vision

School/Classroom Mode · Corporate/Team Mode · Browser extension · Desktop companion · Wearable integration · Health-data correlation · Public API.

---

## 16. User Flows

### Flow 1: First-Time Onboarding *(E-12: disclosure screen added)*

```
Install → Splash → Welcome (3 screens) → Accessibility Disclosure (explicit consent)
→ Permissions Setup → App Selection → [Optional: Name your first preset]
→ Home Dashboard → Start First Session → Complete → See Streak Start
```

### Flow 2: One-Tap Repeat Focus

```
Open App → Home Dashboard (shows last config) → Tap "Start Focus"
→ Session Active → Complete → Stats Updated
```

### Flow 3: Distraction Attempt During Session

```
User opens blocked app → Intercept Screen instantly
→ "Return to Focus" (primary) or "I'm stuck" (secondary)
→ If stuck → Recovery Flow → Resume or End
```

### Flow 4: User Tries to Quit Early

```
Tap End Session → Exit Reason Screen ("Why are you leaving?")
→ Finished task → Complete session (success)
→ Emergency → Immediate exit
→ Stuck/Tired → Recovery Flow → Resume or End
→ Need one app → Deny (strict) or 5-min single-app pass (normal, timer keeps running)
```

### Flow 5: Web-Based Unlock (Phase 2 — deferred)

```
Phone: Tap Emergency Exit → See "Visit fokus.app/unlock"
Other device: Log in → See session details → Generate code (valid 5 min)
Phone: Enter 6-digit code → Session ends (completionReason = unlockCode)
```

### Flow 6: Supervised User Session (Phase 5)

```
Parent sets schedule: "No social media Mon-Fri 3pm-6pm"
→ Child's phone: Session auto-starts at 3pm
→ Child tries to open Instagram → Intercept Screen
→ Child requests unlock → Parent gets notification → Approves/Denies
→ If denied: Session continues
→ At 6pm: Session auto-ends
```

### Flow 7: Social Focus Room (Phase 2 — deferred)

```
User creates room → Sets duration + blocked apps → Shares link
→ Friends join lobby → Host starts session → Shared timer runs
→ "Lucas left early" notification to group → Session completes → Group summary
```

---

## 17. Screen Inventory

### MVP Screens (Phase 1)

| # | Screen | Purpose |
|---|--------|---------|
| 1 | Splash | Brand entry, permission check, routing |
| 2 | Welcome / Onboarding (3 pages) | Communicate value |
| 3 | **Accessibility Disclosure** | Play-policy-critical consent before any settings redirect *(E-12)* |
| 4 | Permissions Setup | Guide platform-specific permissions |
| 5 | App Selection | Choose distracting apps to block |
| 6 | Home Dashboard | Quick start, today summary, streak |
| 7 | Start Focus Session | Configure session (apps, duration, task, mode) |
| 8 | Active Focus Session | Countdown timer, task, blocked apps, progress |
| 9 | Blocked App Intercept | Redirect when blocked app opened |
| 10 | Exit Attempt / Reason | Friction + reason collection before quitting |
| 11 | Recovery Flow | Breathe, stretch, task reset, water, shrink session |
| 12 | Session Complete | Celebrate, show stats, streak update |
| 13 | Profile / Settings | Preferences, notifications, permissions health |

*(Note: the accessibility disclosure is now an explicit numbered screen, shifting later MVP screen numbers by one relative to Blueprint v1.0.)*

### Phase 2 Screens

| # | Screen | Purpose |
|---|--------|---------|
| 14 | Stats Dashboard | Day/week/month, charts, most distracting apps |
| 15 | Streak / Achievements | Streak counter, badges, lock-break balance |
| 16 | Focus Preset Setup | Create/edit reusable configurations |
| 17 | Schedule Management | Add/edit/toggle recurring schedules |
| 18 | Focus Room Lobby | Create or join group sessions |
| 19 | Active Group Focus Room | Shared timer, participants, event feed |
| 20 | Feedback Form | Category, text, optional screenshot |
| 21 | Notifications / Reminders | Manage notification preferences |

### Phase 3 Screens

| # | Screen |
|---|--------|
| 22 | Subscription / Premium Paywall |
| 23 | Lock Break Token Management |

### Phase 4 (iOS-specific)

| # | Screen |
|---|--------|
| 24 | iOS Permissions Setup (FamilyControls authorization) |
| 25 | iOS App/Category Picker (Apple's FamilyActivity Picker) |

### Phase 5 Screens

| # | Screen |
|---|--------|
| 26 | Supervisor Dashboard (web + mobile) |
| 27 | Supervised User Consent Screen |
| 28 | Unlock Request / Approval Flow |
| 29 | AI Coach Chat Interface |
| 30 | Weekly AI Attention Report |
| 31 | Financial Stakes Setup |

---

## 18. Security, Privacy & Compliance

### Privacy Principles

- No selling or sharing of usage data, ever
- Behavioral data (app usage, distraction attempts) treated as sensitive personal data
- Local processing by default; cloud sync is user-initiated (Phase 2+)
- Collect only what is needed
- Store app identifiers, never in-app content or messages
- Let users export and delete all their data
- **Current scope: zero network permission usage, no analytics SDK** (`fokus-specs` NFR)

### Data Storage

| Data | Location | Encryption |
|------|----------|-----------|
| Session history | Local (Drift) + optional cloud sync (Firestore, Phase 2+) | At rest (Android Keystore / iOS Keychain) |
| Distraction attempts | Local | At rest |
| Recovery events | Local | At rest |
| User account | Firebase Auth (Phase 2+) | Google-managed |
| Room state | Firestore (Phase 2+) | Google-managed (TLS in transit) |
| Unlock codes | Firestore, 5-min TTL, auto-deleted (Phase 2+) | TLS in transit |
| AI insights | Local | At rest |
| Supervised user data | Firestore, separate collection with access rules (Phase 5) | TLS + Firestore rules |

### Compliance

| Regulation | Applicability | Key Requirements |
|-----------|--------------|-----------------|
| **Swiss nFADP** | Primary | Consent, right to access/delete, data minimization, cross-border transfer notice |
| **GDPR** | EU/EEA | + DPO if at scale, DPIA for high-risk processing |
| **COPPA** | US under 13 | Parental consent, limited data collection |
| **Google Play policies** | Android | Target API 35+, accessibility-service disclosure, permission usage explanations |
| **Apple App Store** | iOS | Screen Time API entitlement, privacy labels, ATT |

### Supervised Mode Privacy (Phase 5)

- Explicit consent before linking; supervisors see metrics only, never content
- Separate Firestore collection, strict access rules; revocable any time
- Under 16 (CH nFADP) / under 13 (US COPPA): guardian consent required

---

## 19. QA & Testing Strategy

### Device Test Matrix

**Android (priority):** Samsung Galaxy S-series · Google Pixel · Xiaomi/Redmi · OnePlus · Oppo/Vivo (if resources permit)
**Android version coverage:** API 26 (Android 8) → API 35 (Android 15)
**iOS (Phase 4):** iPhone 12+ on iOS 16, 17, 18

### Critical Test Flows

| # | Test | Priority |
|---|------|----------|
| 1 | First-run onboarding completes, all permissions granted | P0 |
| 2 | Permission denied/revoked mid-session — graceful degradation (→ failedPermissions ≤ 30 s) | P0 |
| 3 | Top 20 popular apps blocked correctly on Android | P0 |
| 4 | Blocking works after device reboot | P0 |
| 5 | Session survives app crash / process kill | P0 |
| 6 | Recovery flow completes and session resumes | P0 |
| 7 | Exit flow captures reason correctly | P0 |
| 8 | Streak increments correctly across timezone/day boundary | P0 |
| 9 | Battery optimization doesn't kill foreground service (Samsung, Xiaomi) | P0 |
| 10 | Concurrent notifications don't interfere with blocking overlay | P1 |
| 11 | Schedule triggers session at correct local time | P1 |
| 12 | Social room: join, focus, leave early, complete | P1 |
| 13 | Unlock code: generate, expire, validate, reject expired | P1 |
| 14 | Premium paywall gates features correctly | P1 |
| 15 | Lock Break token earned at milestone, redeemed correctly | P1 |
| 16 | Supervised mode: link, consent, schedule, request unlock, revoke | P2 |
| 17 | iOS shielding applies/removes correctly via ManagedSettings | P0 (Phase 4) |

### Testing Week (Week 4 of Phase 1)

Dedicate Phase-1 week 4 to testing, hardening, and bug fixing. An app blocker that doesn't reliably block is worse than no app — it destroys trust and generates 1-star reviews.

---

## 20. Metrics & Success Criteria

### North Star Metric

**Weekly active focus hours per user** — captures retention and engagement.

### Key Metrics by Phase

#### Phase 1 (MVP)

| Metric | Target (Month 1) | Target (Month 3) |
|--------|------------------|------------------|
| Downloads | 500 | 3,000 |
| D1 retention | 40% | 50% |
| D7 retention | 25% | 35% |
| Avg. sessions per user per week | 2 | 4 |
| **Recovery resume-rate** | 50% | 60% |
| Permission grant rate (onboarding) | 70% | 80% |

*(E-18: "recovery flow → resume rate" standardized to "recovery resume-rate", matching `fokus-specs` §3.6 and the `recovery_resumed`/`recovery_exited` analytics events.)*

#### Phase 2-3

| Metric | Target (Month 6) |
|--------|------------------|
| MAU | 10,000 |
| DAU/MAU ratio | 30% |
| Room feature adoption | 15% |
| AI suggestion acceptance rate | 25% |
| Free → Premium conversion | 4% |
| Post-session satisfaction (% "Great") | 60% |

#### Phase 4-5

| Metric | Target (Month 12) |
|--------|-------------------|
| Total users (Android + iOS) | 50,000 |
| Premium subscribers | 2,000 |
| Monthly recurring revenue | CHF 8,000+ |
| App Store rating | 4.5+ |
| Supervised accounts linked | 500 |
| NPS | 40+ |

---

## 21. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Android OEM battery optimization kills blocking service | High | Critical | Dedicated Samsung/Xiaomi testing; in-app battery guide; proactive permission health checks |
| Apple rejects FamilyControls entitlement | Medium | High | Apply at Phase-4 start; friction-based fallback |
| Users bypass by uninstalling FOKUS | Medium | Medium | Accept it — focus on willing users; unlock-code friction; strict mode + Device Admin opt-in |
| Low retention after install | High | High | Recovery system, streaks, reminders, micro-feedback |
| Google Play rejects app over accessibility usage | Low | High | Clear disclosure (mandatory screen), position as productivity tool, follow Play guidelines exactly |
| Competitor copies recovery system | Medium | Low | Move fast; community moat; easy to copy, hard to execute well |
| Financial stakes violate Swiss fintech regs | Medium | Medium | Legal consult first; charity-only start; remove if compliance too costly |
| Team burnout (2–3 people) | Medium | High | Strict phase gating; cut scope before extending hours |
| AI features feel gimmicky | Medium | Medium | Start with simple pattern analysis; validate; label "beta" |
| Parental control privacy backlash | Low | Medium | Mandatory consent, transparency, clear boundaries, easy revocation |

---

## 22. Budget Estimate

### First 12 Months (Lean)

| Category | Cost (CHF) | Notes |
|----------|-----------|-------|
| Google Play Developer | 25 (one-time) | Required for Android |
| Apple Developer | 99/year | Required for iOS (Phase 4) |
| Firebase (Blaze) | 0–100/month | Free tier covers early Phase 2; scales with rooms/sync |
| PostHog | 0 | Free tier: 1M events/month (only when analytics adopted) |
| Domain (fokus.app / fokusapp.ch) | 50–100/year | Landing + web unlock portal |
| Figma | 0–15/month | Free tier for small team |
| Marketing (pre-launch + launch) | 500–1,000 | Student sponsorships, small social ads |
| Legal consultation | 300–500 | Financial stakes compliance, privacy review |
| Hosting (web portal) | 0 | Firebase Hosting / Vercel free |
| **Total (Year 1)** | **~CHF 1,200–3,000** | Lean, mostly sweat equity |

### Revenue Break-Even Estimate

At CHF 4.99/month, 4% conversion:
- 1,000 MAU → 40 premium → ~CHF 200/month
- 5,000 MAU → 200 premium → ~CHF 1,000/month
- 10,000 MAU → 400 premium → ~CHF 2,000/month (covers costs)

Break-even at ~**5,000–10,000 MAU**.

---

## 23. Open Questions & Future Exploration

| # | Question | Context | Decision Needed By |
|---|----------|---------|-------------------|
| 1 | Web unlock portal: PWA or simple web page? | PWA could become a desktop companion; a page ships faster | Phase 2 start |
| 2 | Should Focus Rooms have text chat? | Wireframes advise against (distraction); light encouragement might help | Phase 2 start |
| 3 | Charity partners for financial stakes? | Swiss Red Cross? Reforestation? One Tree Planted? | Phase 5 start |
| 4 | AI coaching: Claude, OpenAI, or on-device only? | Cost/privacy/quality tradeoffs | Phase 5 start |
| 5 | Should Lock Break tokens ever be purchasable? | Current: earned only; buying risks integrity | After Phase 3 data |
| 6 | Apple Watch / Wear OS support? | Quick session start from wrist; dev cost high | After iOS launch |
| 7 | Is "Fokus" trademarkable in CH/EU? | "Focus" variants common | Before Phase 1 |
| 8 | Direct APK distribution outside Play Store? | Avoids Play cut; reduces discoverability | After Phase 3 |
| 9 | **How to handle "always-on" apps (navigation, music)?** | Users need Spotify/Maps during focus — auto-whitelist, or a user allowlist? Distinct from the never-blockable safety set (§6.1). **[DECISION-NEEDED D-E]** | **Phase 1 design** |
| 10 | Supervised-mode data: local on supervisor device or cloud only? | Local more private; cloud enables web dashboard | Phase 5 design |

---

## 24. Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-03-15 | 1.0 | Initial blueprint consolidating PRD, Wireframes, Architecture, Project Plan, competitive analysis. |
| 2026-07-02 | 1.1 (this doc) | **Cleaned full-scope reference.** Added Inconsistency Register (24 findings: 6 DECISION-NEEDED, 18 editorial/contract-align). Aligned session states, recovery-type & exit-reason enums, streak definition, durations, and free-tier caps to `docs/CONTRACTS.md` (CONTRACTS wins). Split streak-milestone badges from achievements (E-1). Phase-tagged Social Focuser (E-2) and supervisor fields (E-17). Fixed recovery module naming/duration/semantics (E-3/4/11). Added mandatory accessibility disclosure screen to onboarding/flows/screen-inventory (E-12). Clarified offline AI split (E-7), local-only feedback (E-9), Flutter/Drift stack per DECISIONS D-001. Reclassified Premium billing P0→P1 (D-A). Does **not** alter current build scope, `fokus-specs.md`, or `docs/`. |

---

*This is the FOKUS full-scope **vision** reference. For the binding current build, see root `fokus-specs.md` (behavior) and `docs/CONTRACTS.md` (interfaces/enums/constants). When those disagree with this file on a current-scope item, they win.*
