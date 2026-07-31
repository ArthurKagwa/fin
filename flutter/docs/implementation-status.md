# Implementation status
_Last updated: 2026-07-31_

| ID | Requirement | Status | Where | Notes |
|----|-------------|--------|-------|-------|
| FR-01 | Email/password sign-up | Not started | — | |
| FR-02 | Email verification before spending | Not started | — | |
| FR-03 | Per-user currency + timezone | Done | `flutter/lib/core/utils/currency.dart`, `features/onboarding/` | Searchable country picker over every country; currency fixed after onboarding, with a worked example shown before it is saved |
| FR-04 | Income logging (any source, any frequency) | Not started | — | |
| FR-05 | Paycheque: gross + itemised deductions | Not started | — | |
| FR-06 | Budget buckets with planned amounts + goals | In progress | `flutter/lib/features/buckets/` | Create/read/update/delete done; per-month planned amounts now snapshot into `monthlyPlans/` (FR-17). Goal progress still needs carry-over balances from allocation (FR-08) |
| FR-07 | Daily expense entry (≤4 taps) | Done | `features/expenses/` | Cash-register amount entry, pre-selected bucket, Undo on the save snackbar |
| FR-08 | Allocation of income across buckets | Not started | — | |
| FR-09 | Unallocated-funds tracking | Not started | — | |
| FR-10 | Recurring payment registry | Done | `features/recurring/` | Create on a full screen with per-field validation and a start-date picker |
| FR-11 | Amount-change history for recurring payments | Not started | — | |
| FR-12 | Dashboard: bucket status + pace | Done | `flutter/lib/features/planning/` | Pace-adjusted three-state ladder (on track / off pace / off plan) on the summary card and every bucket card |
| FR-17 | Planned vs actual income and spend | Done | `flutter/lib/features/planning/` | Expected income sources + per-bucket planned spend, snapshotted per month; dashboard card plus `/plan` report with month picker |
| FR-13 | Upcoming recurring charges | Not started | — | |
| FR-14 | CSV import with mapping + dedup | Not started | — | Surfaced in Settings as a disabled "Coming soon" row |
| FR-18 | Export a month as a PDF statement | Done | `flutter/lib/features/reports/` | Summary, money in by source, spend by bucket and every transaction; shared via the platform sheet |
| FR-15 | 3-month trial, then freemium gate | Not started | — | |
| FR-16 | Freemium limits (5 buckets, 3 recurring) | Not started | — | |
| FR-19 | Transactions list with correction | Done | `features/expenses/presentation/transactions_screen.dart` | Month picker, grouped by day, swipe deletes with Undo; deletes are soft so Undo is a field flip |
| US-01 | Signup: email + password, currency confirmation | Not started | — | |
| US-04 | Log income (paycheque or one-off) | Not started | — | |
| US-05 | Create and manage buckets | Done | `flutter/lib/features/buckets/` | Full CRUD: create, list, edit (name/planned/goal), delete with confirmation |
| US-06 | Allocate income to buckets | Not started | — | |
| US-07 | Log daily expenses (fast path) | Done | `features/expenses/presentation/add_expense_sheet.dart` | |
| US-08 | Overspend: warn, never block | Not started | — | |
| US-09 | Add recurring payment + first rate period | Done | `features/recurring/presentation/recurring_form_screen.dart` | |
| US-10 | Confirm / skip an occurrence | Not started | — | |
| US-11 | Record amount change (new rate period) | Not started | — | |
| US-13 | Dashboard with pace framing | Done | `flutter/lib/features/planning/` | Headline "left to spend", bullet bars with a pace tick, straight-line projection once ≥25% of the month has run |
| US-24 | Set expected income for a month | Done | `flutter/lib/features/planning/presentation/plan_editor_screen.dart` | Named sources so a shortfall says which income didn't land; carried forward month to month |
| US-25 | Compare a past month against its own plan | Done | `flutter/lib/features/planning/presentation/plan_vs_actual_screen.dart` | Month picker; months with no recorded plan are labelled as shown against current bucket amounts |
| US-17 | Trial management + free-tier gating | Not started | — | |
| US-18 | Admin / ops tooling | Not started | — | |
| US-20 | Bucket planning + goals | Not started | — | |
| US-21 | Paycheque deductions | Not started | — | |
| US-22 | Deduction prefill from prior paycheque | Not started | — | |
| US-23 | Earnings report (gross vs take-home) | Done | `flutter/lib/features/earnings/` | Leads with the effective deduction rate, weighted by gross; per-month split and a breakdown of what takes it |
| US-26 | Account details | Done | `flutter/lib/features/profile/presentation/account_screen.dart` | Email + verification state, currency, timezone, member since, sign-out with confirmation |

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

## Planned vs actual — notes for whoever picks this up next

- **Firestore**: `users/{uid}/monthlyPlans/{YYYY-MM}` = `{month, expectedIncomes[], bucketPlans{}, createdAt, updatedAt}`.
  Covered by the existing `users/{uid}/{document=**}` rule, and doc-ID reads plus a
  single-field `month` query, so neither `firestore.rules` nor
  `firestore.indexes.json` needed changing.
- **Snapshot timing**: the current month is frozen once, from the dashboard's
  `initState`. Past months are never retro-written — a month with no snapshot
  renders against current bucket defaults and says so.
- **Pace is straight-line**, which misreads a bucket dominated by one fixed
  charge (rent on the 1st reads as ahead of pace all month). The three-state
  ladder keeps that amber rather than red. Fixing it properly means making the
  report aware of recurring payments — deliberately out of scope here.
- **Two things were removed from the dashboard rather than left showing zeros**:
  the unallocated-funds banner (`unallocatedMinor` is hardcoded `0` until
  FR-08) and the goal-progress percentage (needs carry-over balances). Both
  should come back with allocation. `dashboard_repository.dart` and
  `dashboard_summary.dart` are untouched and unused, waiting for that work.

## Money handling — read this before touching an amount

Amounts are integer **minor units** and the decimal places come from the
currency, never from a constant.

- `core/utils/currency.dart` owns the facts: `currencyDecimals` (0 for
  UGX/RWF/JPY/XOF…, 3 for KWD/BHD/OMR…, 2 for everything else),
  `currencySymbol` with an ISO-code fallback, and every country the picker
  offers.
- `formatMoney(minorUnits, currency:)` is the only way to render money. The
  same integer 1200 is `$12.00`, `USh 1,200` and `KWD 1.200` — before this it
  printed `1,200` regardless, which was right for Uganda and 100x wrong for
  the other twelve countries the picker offered.
- `core/widgets/money_field.dart` is the only way to *enter* money.
  Cash-register entry: digits fill from the right, so 1-2-5-0 reads 12.50 and
  no keystroke can produce an unparseable value. Read it back with
  `moneyFromField`; use `moneyFieldIsEmpty` where blank and zero differ.
- Do **not** reintroduce `int.tryParse(text)` on an amount. Null meant "left
  blank", so `12.50` silently wiped saved amounts in the bucket form and
  dropped buckets from the monthly plan.

No migration exists or is needed — this landed while data was dev-only. If
that ever stops being true, every stored amount needs multiplying by the
account currency's exponent.

## Settings — notes

- Settings was previously a mockup: 8 of its 9 rows had `onTap: () {}` and the
  "Trial ends in 62 days" subtitle was invented — there are no trial fields in
  `UserProfile` at all. That line is gone.
- Rows for features that don't exist yet (Import, Evening reminder, Plan &
  billing) render disabled with a "Coming soon" tag rather than silently doing
  nothing, which reads as a bug.
- Currency is deliberately *not* editable, matching the promise made during
  onboarding. The account screen says so explicitly so it doesn't read as a
  missing setting.
- **New dependencies**: `pdf` and `printing`, for the statement export. They
  need a `flutter pub get` — `pubspec.lock` could not be regenerated in the
  environment this was written in.
- The PDF is built from `pw.Row`/`pw.Column` primitives rather than the
  package's table helpers, which have moved between major versions. Text is
  kept ASCII-only so the embedded Helvetica renders every glyph.

## Open questions
- **Q-01**: Firebase project not yet created. Run `flutterfire configure` to generate `firebase_options.dart` and `android/app/google-services.json`.
- **Q-02**: `minSdk` currently uses Flutter's default (`flutter.minSdkVersion`). PRD does not specify minimum Android version — confirm if < API 21 devices must be supported.
- **Q-03**: Color seed for receipt/screenshot capture ADR (Q-01 through Q-05) unresolved — see `flutter/docs/adr-001-receipt-interpretation.md`.
