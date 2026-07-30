# Implementation status
_Last updated: 2026-07-30_

| ID | Requirement | Status | Where | Notes |
|----|-------------|--------|-------|-------|
| FR-01 | Email/password sign-up | Not started | — | |
| FR-02 | Email verification before spending | Not started | — | |
| FR-03 | Per-user currency + timezone | Not started | — | |
| FR-04 | Income logging (any source, any frequency) | Not started | — | |
| FR-05 | Paycheque: gross + itemised deductions | Not started | — | |
| FR-06 | Budget buckets with planned amounts + goals | In progress | `flutter/lib/features/buckets/` | Create/read/update/delete done; dashboard pace/allocation tracking against goals is separate (FR-12) |
| FR-07 | Daily expense entry (≤4 taps) | Not started | — | |
| FR-08 | Allocation of income across buckets | Not started | — | |
| FR-09 | Unallocated-funds tracking | Not started | — | |
| FR-10 | Recurring payment registry | Not started | — | |
| FR-11 | Amount-change history for recurring payments | Not started | — | |
| FR-12 | Dashboard: bucket status + pace | Not started | — | |
| FR-13 | Upcoming recurring charges | Not started | — | |
| FR-14 | CSV import with mapping + dedup | Not started | — | |
| FR-15 | 3-month trial, then freemium gate | Not started | — | |
| FR-16 | Freemium limits (5 buckets, 3 recurring) | Not started | — | |
| US-01 | Signup: email + password, currency confirmation | Not started | — | |
| US-04 | Log income (paycheque or one-off) | Not started | — | |
| US-05 | Create and manage buckets | Done | `flutter/lib/features/buckets/` | Full CRUD: create, list, edit (name/planned/goal), delete with confirmation |
| US-06 | Allocate income to buckets | Not started | — | |
| US-07 | Log daily expenses (fast path) | Not started | — | |
| US-08 | Overspend: warn, never block | Not started | — | |
| US-09 | Add recurring payment + first rate period | Not started | — | |
| US-10 | Confirm / skip an occurrence | Not started | — | |
| US-11 | Record amount change (new rate period) | Not started | — | |
| US-13 | Dashboard with pace framing | Not started | — | |
| US-17 | Trial management + free-tier gating | Not started | — | |
| US-18 | Admin / ops tooling | Not started | — | |
| US-20 | Bucket planning + goals | Not started | — | |
| US-21 | Paycheque deductions | Not started | — | |
| US-22 | Deduction prefill from prior paycheque | Not started | — | |
| US-23 | Earnings report (gross vs take-home) | Not started | — | |

## Scaffold (done)
- [x] `flutter create` with package `com.arthurasasira.fintrack`
- [x] All Firebase SDK dependencies added
- [x] Riverpod codegen configured (`riverpod_generator`, `build_runner`, `riverpod_lint`)
- [x] Feature-first `lib/` structure: `core/` + `features/{auth,dashboard,expenses,income,recurring,buckets,settings}`
- [x] Editorial theme: Material 3, Playfair Display + DM Sans, terracotta/cream palette
- [x] GoRouter with auth redirect + 4-tab `StatefulShellRoute`
- [x] `AppFailure` sealed class hierarchy
- [x] `FirebaseAuthRepository` with `AuthFailure` mapping
- [x] `authStateProvider` (keepAlive) driving router redirect
- [x] Persistent floating `+ Expense` FAB on `ScaffoldWithNav`
- [x] Domain model stubs: `AppUser`, `Bucket`, `Expense`, `IncomeEvent`, `RecurringPayment`, `Occurrence`
- [x] Repository interfaces + `UnimplementedError` stubs for all features
- [x] `firestore.rules` (default deny), `firebase.json`, `firestore.indexes.json`
- [x] `flutter analyze` clean

## Open questions
- **Q-01**: Firebase project not yet created. Run `flutterfire configure` to generate `firebase_options.dart` and `android/app/google-services.json`.
- **Q-02**: `minSdk` currently uses Flutter's default (`flutter.minSdkVersion`). PRD does not specify minimum Android version — confirm if < API 21 devices must be supported.
- **Q-03**: Color seed for receipt/screenshot capture ADR (Q-01 through Q-05) unresolved — see `flutter/docs/adr-001-receipt-interpretation.md`.
