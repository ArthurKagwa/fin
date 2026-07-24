---
name: flutter-firebase-android
description: Implement and maintain a Flutter Android app against a written spec pack (SRD/SDD/PRD/user stories) using Riverpod and the Firebase ecosystem (Auth, Firestore, Storage, FCM, Crashlytics, Analytics, Remote Config, Cloud Functions, App Check). Use this skill whenever the user asks to build, extend, wire up, refactor, or debug a Flutter app that touches Firebase or Riverpod, whenever they point at a docs folder and say "build this" / "implement FR-03" / "what's left", and whenever spec documents and Flutter code both appear in the same request — even if they never say the words "skill", "Riverpod", or "spec". Also use for Android-native Firebase configuration (google-services.json, Gradle plugins, minSdk, permissions, release signing) and for questions about whether the code still matches the docs.
---

# Flutter + Firebase, Spec-Driven

Build and maintain a Flutter Android app whose source of truth is a written spec pack, not the conversation.

Claude can already write Dart. That is not the hard part and this skill spends no words on it. The failures that actually sink this kind of work are: implementing features nobody specified, letting Firebase calls leak into widgets, shipping a Firestore feature with no security rules, and losing track — across sessions — of which requirements are done. Everything below targets those.

## Prime directive: the docs rule, and silence is not permission

The spec pack is the contract. If a behaviour is not in the docs, it is not a requirement, however obvious it seems. Inventing "sensible" features is the most expensive failure mode here, because it looks like progress and nobody catches it until review.

When the docs are silent, ambiguous, contradict each other, or contradict the existing code: **stop and ask the user.** Do not assume, do not mark `[ASSUMPTION]` and continue, do not let the code silently win.

Applying that literally would stall on every third line, so batch it:

- Collect open questions **during planning, before writing code.**
- Ask them in **one batch per work slice** (use `AskUserQuestion` if available; otherwise a numbered list, options where you can offer them).
- Once the slice is agreed, implement the whole slice without further check-ins.
- If a genuinely blocking unknown surfaces mid-implementation, stop, park the partial work, and ask — do not guess to keep momentum.

A question worth stopping for is specific and decision-shaped: *"SRD §4.2 says sessions expire but doesn't say whether expiry forces re-auth or silent token refresh — which?"* Not: *"how should auth work?"*

Write the answers back into the docs (or ask the user to), otherwise the next session re-litigates them.

## Workflow

### 1. Orient — read before writing

Find the spec pack. Check `/docs`, `docs/`, `specs/`, `doc/` at the repo root. Filenames vary (`srd.md`, `sdd.md`, `01-prd.md`, `02-user-stories.md`); read what's there rather than expecting a fixed layout. If no spec pack exists, say so and stop — this skill has nothing to execute. Offer to produce one first (a BA/PM spec skill may be available).

Extract a requirement index: every ID (`FR-01`, `NFR-01`, `US-01`, or whatever convention the docs use), its statement, and its acceptance criteria. Requirements without testable criteria are a defect in the docs — list them as open questions, don't paper over them.

### 2. Detect codebase state

Greenfield and brownfield need different opening moves, and guessing wrong wastes a lot of work. Check, in order:

| Signal | Tells you |
|---|---|
| `pubspec.yaml` exists | Project exists; read deps before adding any |
| `lib/` layout | The architecture actually in use — match it or argue explicitly for changing it |
| `firebase_options.dart`, `android/app/google-services.json` | Firebase already configured; which project/flavors |
| `android/app/build.gradle(.kts)` | minSdk, Gradle plugin wiring, signing, flavors |
| `firestore.rules`, `storage.rules`, `firebase.json` | Whether rules are version-controlled (they must be) |
| `docs/implementation-status.md` | Prior sessions' traceability ledger — read it first |
| `test/` | Existing test conventions |

Brownfield rule: the existing project's conventions beat this skill's defaults. If they conflict with the SDD, that's a contradiction — stop and ask.

Greenfield: read `references/architecture-riverpod.md` before scaffolding.

### 3. Plan a slice and confirm it

Never implement the whole spec in one pass. Pick a coherent slice — usually one user story or one FR plus its NFRs — and present, briefly:

- Requirement IDs in the slice
- Files to create/modify
- Firebase surfaces touched (collections, rules, functions, config)
- Open questions blocking the slice

Get agreement, then build. This checkpoint is where ambiguity is cheap to fix; after code exists it isn't.

### 4. Implement

Follow `references/architecture-riverpod.md` for layering and Riverpod conventions, `references/firebase-android.md` for Firebase and Android-native wiring. Read the relevant file before writing code in that area — both encode constraints that are easy to get plausibly wrong.

Two rules that override convenience, always:

1. **No Firebase type crosses into the presentation layer.** No `FirebaseFirestore.instance`, `User`, `DocumentSnapshot`, or `FirebaseException` in a widget. Repositories own the SDK; the rest of the app sees domain models and domain failures. This is what makes the app testable and what makes swapping or mocking Firebase possible at all.
2. **Every requirement maps to code, and every non-trivial change maps to a requirement.** If you can't name the ID a change serves, you're inventing.

### 5. Verify before claiming done

A slice is done when all of these hold — not when the code compiles:

- [ ] `flutter analyze` clean (no new warnings)
- [ ] `dart format` applied
- [ ] Tests exist for the slice's logic and pass (`flutter test`); repositories and notifiers are unit-tested, not just widgets
- [ ] Every acceptance criterion in the slice's docs is demonstrably satisfied — walk them one by one
- [ ] **Security rules updated** for any new Firestore collection or Storage path, and reasoned about — a feature with permissive rules is not shipped, it's breached
- [ ] Firestore composite indexes declared for any new compound query
- [ ] Ledger updated (below)

Run the commands. Don't assert a build is clean without having run it; if the environment can't run Flutter, say that explicitly rather than implying verification happened.

### 6. Maintain the traceability ledger

Sessions have no memory of each other. Without a written record, every session re-derives status from the code and drifts. Maintain `docs/implementation-status.md`:

```markdown
# Implementation status
_Last updated: YYYY-MM-DD_

| ID | Requirement | Status | Where | Notes |
|----|-------------|--------|-------|-------|
| FR-01 | Email/password sign-in | Done | lib/features/auth/ | |
| FR-02 | Offline draft sync | In progress | lib/features/drafts/ | Conflict policy unresolved — see Q-03 |
| FR-07 | Push on new comment | Blocked | — | Q-01 |

## Open questions
- **Q-01** (FR-07): SRD silent on notification grouping. Asked 2026-07-16.
```

Update it in the same change as the code. A ledger that lags the code is worse than no ledger, because it's believed.

## Reference files

- `references/architecture-riverpod.md` — layering, feature structure, Riverpod conventions, testing patterns. Read before writing providers, repositories, or scaffolding a project.
- `references/firebase-android.md` — per-product conventions (Auth, Firestore, Storage, FCM, Crashlytics, Analytics, Remote Config, Functions, App Check) and Android-native config. Read before touching any Firebase surface.

## Versions and APIs

Firebase and FlutterFire APIs move faster than any skill can track, and confidently-wrong snippets cost more time than they save. Never assert a plugin version, minSdk floor, or API signature from memory. Read `pubspec.yaml`, `pubspec.lock`, and the Gradle files for what this project actually uses; consult current FlutterFire/Firebase documentation for anything you're not reading off disk. If the docs can't be reached, say what you're unsure of instead of guessing.
