# Implementation status
_Last updated: 2026-07-31 — post benchmark-remediation pass._

This pass closed every gap `benchmark-evaluation.md` flagged as P0/P1: editing
everywhere, bucket-delete safety, income allocation with carry-over, local
reminders, dark mode, App Check activation, account deletion, CSV import, and
a spend trend + search/filter. See `benchmark-evaluation.md` for the
before/after scorecard.

| ID | Requirement | Status | Where | Notes |
|----|-------------|--------|-------|-------|
| FR-01 | Email/password sign-up | Done | `features/auth/` | Sign up, sign in, Google sign-in; router redirects unverified/no-currency users before they reach the app |
| FR-02 | Email verification before spending | Done | `features/auth/presentation/verify_email_screen.dart`, `core/router/router.dart` | Router redirect blocks every route until `emailVerified`; screen polls every 5s and offers resend with a 30s cooldown |
| FR-03 | Per-user currency + timezone | Done | `core/utils/currency.dart`, `features/onboarding/` | Searchable country picker; currency fixed after onboarding |
| FR-04 | Income logging (any source, any frequency) | Done | `features/income/` | Add/edit/delete (soft, with Undo), monthly total |
| FR-05 | Paycheque: gross + itemised deductions | Done | `features/income/presentation/add_income_sheet.dart` | Gross + itemised deduction rows, take-home derived live, deductions-exceed-gross blocked client-side |
| FR-06 | Budget buckets with planned amounts + goals | Done | `features/buckets/` | Full CRUD; archive (not hard-delete) once a bucket has any expense/recurring/allocation reference; goal progress now real (`Bucket.balanceMinor / goalMinor`) |
| FR-07 | Daily expense entry (≤4 taps) | Done | `features/expenses/` | Cash-register amount entry, pre-selected bucket, Undo on the save snackbar, tap-to-edit |
| FR-08 | Allocation of income across buckets | Done | `features/allocations/` | Doc-per-allocation; "Allocate" action on each income row opens a bottom sheet against the global unallocated pool |
| FR-09 | Unallocated-funds tracking | Done | `features/profile/`, `features/income/presentation/income_list_screen.dart`, `features/dashboard/` | `UserProfile.unallocatedMinor`, a running total maintained transactionally; banner on both the income list and the dashboard |
| FR-10 | Recurring payment registry | Done | `features/recurring/` | Create/rename/rebucket on a full screen; "Custom" interval now selectable |
| FR-11 | Amount-change history for recurring payments | Done | `features/recurring/presentation/recurring_form_screen.dart` (`_addRateChangeDialog`) | Appends a new `RatePeriod`; history preserved and already read by `currentAmountMinor`/`amountAt` |
| FR-12 | Dashboard: bucket status + pace | Done | `features/planning/`, `features/dashboard/` | Pace-adjusted three-state ladder; unallocated banner and real goal-progress % restored |
| FR-13 | Upcoming recurring charges | Done | `features/recurring/presentation/recurring_screen.dart` | Confirm/skip within a 14-day lookahead |
| FR-14 | CSV import with mapping + dedup | Done | `features/imports/` | Pick file → map columns → preview with duplicates flagged (not excluded) → commit; single bucket per import |
| FR-15 | 3-month trial, then freemium gate | Not started | — | Specified only (`docs/01-prd.md` FR-16); no trial/plan fields exist on `UserProfile` |
| FR-16 | Freemium limits (5 buckets, 3 recurring) | Not started | — | Same as above |
| FR-17 | Planned vs actual income and spend | Done | `features/planning/` | Expected income sources + per-bucket planned spend, snapshotted per month |
| FR-18 | Export a month as a PDF statement | Done | `features/reports/` | Summary, money in by source, spend by bucket, every transaction |
| FR-19 | Transactions list with correction | Done | `features/expenses/presentation/transactions_screen.dart` | Month picker, search (payee/note), bucket filter chips, swipe-delete with Undo, tap-to-edit |
| US-01 | Signup: email + password, currency confirmation | Done | `features/auth/`, `features/onboarding/` | |
| US-04 | Log income (paycheque or one-off) | Done | `features/income/` | |
| US-05 | Create and manage buckets | Done | `features/buckets/` | Create, list, edit, archive/unarchive, delete-when-safe |
| US-06 | Allocate income to buckets | Done | `features/allocations/` | |
| US-07 | Log daily expenses (fast path) | Done | `features/expenses/presentation/add_expense_sheet.dart` | |
| US-08 | Overspend: warn, never block | Done | `features/dashboard/`, `features/planning/` | Bucket cards go red/amber but every write path still succeeds — overspending was never blocked at the repository layer |
| US-09 | Add recurring payment + first rate period | Done | `features/recurring/presentation/recurring_form_screen.dart` | |
| US-10 | Confirm / skip an occurrence | Done | `features/recurring/presentation/recurring_screen.dart`, `recurring_repository.dart` | Confirm writes an expense + status doc + bucket balance decrement in one batch |
| US-11 | Record amount change (new rate period) | Done | `features/recurring/presentation/recurring_form_screen.dart` | |
| US-13 | Dashboard with pace framing | Done | `features/planning/` | |
| US-17 | Trial management + free-tier gating | Not started | — | |
| US-18 | Admin / ops tooling | Not started | — | Out of scope for the mobile client per the PRD (Could priority) |
| US-20 | Bucket planning + goals | Done | `features/buckets/`, `features/dashboard/` | |
| US-21 | Paycheque deductions | Done | `features/income/` | |
| US-22 | Deduction prefill from prior paycheque | Not started | — | |
| US-23 | Earnings report (gross vs take-home) | Done | `features/earnings/` | |
| US-24 | Set expected income for a month | Done | `features/planning/presentation/plan_editor_screen.dart` | |
| US-25 | Compare a past month against its own plan | Done | `features/planning/presentation/plan_vs_actual_screen.dart` | |
| US-26 | Account details | Done | `features/profile/presentation/account_screen.dart` | Now includes account deletion (danger zone) |

## What this pass added, and how it's built

### Editing everywhere
`ExpenseRepository.updateExpense`, `IncomeRepository.updateIncomeEvent` /
`deleteIncomeEvent` / `restoreIncomeEvent`, and
`RecurringRepository.updateDetails` / `addRatePeriod` / `setEndDate` /
`hasLinkedExpenses` / `deleteRecurringPayment` are all new. `AddExpenseSheet`
and `AddIncomeSheet` take an optional model to edit (same `isEditing`
template as `BucketFormScreen`); `TransactionsScreen` and
`income_list_screen.dart` both gained a `Dismissible` + tap-to-edit.
Recurring payments are "stopped" (`setEndDate`) rather than deleted once they
have confirmed history — true delete is only offered when
`hasLinkedExpenses` is false.

### Bucket archive semantics (fixes the reconciliation bug)
`Bucket.archivedAt`/`isArchived` came back (they existed before this pass,
were removed, and are now reintroduced). `BucketRepository.watchAllBuckets()`
is unfiltered; `watchActiveBuckets()` filters archived buckets out
client-side (no composite index needed for a collection this small — see
`hasReferences`, which runs three parallel `.limit(1)` existence checks
across expenses/recurring/allocations rather than a full count).
`PlanRepository.watchPlanVsActual` now sources buckets from
`watchAllBuckets()`, not `watchActiveBuckets()` — this is the actual fix for
the bug `benchmark-evaluation.md` traced: an archived/deleted bucket's
historical spend used to count in the grand total with no per-bucket line to
reconcile against; now it keeps one. Covered by a new test in
`plan_vs_actual_test.dart`.

### Income allocation + carry-over (FR-08/FR-09) — the core envelope mechanic
New `users/{uid}/allocations/{id}` collection: `{incomeEventId, bucketId,
amountMinor, createdAt}`, one doc per allocation chunk. Two running totals,
maintained transactionally (never recomputed from history):
- `Bucket.balanceMinor` — the envelope's balance. `addExpense` decrements it,
  `deleteExpense`/`restoreExpense`/`updateExpense` reverse/reapply it
  (all three are now `runTransaction`s, not blind updates — they need to
  read the old amount/bucket first), `RecurringRepository.confirmOccurrence`
  decrements it in its existing batch, `AllocationRepository.allocate`
  increments it. It never resets between months, so it *is* the rollover
  FR-21/goal-progress needs — no separate "carried over" figure exists.
- `UserProfile.unallocatedMinor` — the "ready to assign" pool.
  `IncomeRepository.addIncomeEvent` increments it; `allocate` decrements it
  inside a transaction that rejects (`ConflictFailure`) over-allocating;
  editing/deleting an income event with any allocation against it is blocked
  in the UI (`AllocationRepository.hasAllocationsForIncomeEvent`) — the safe
  default is "unallocate first," not automatic rebalancing.

`dashboard_repository.dart`/`dashboard_summary.dart` (the pre-existing,
unused files this note previously said were "waiting for this work") are
**deleted** — the real dashboard has run on `PlanVsActual` since before this
pass, and reviving the old dead code would have meant two competing data
paths. The unallocated banner and goal-progress percentage that were
deliberately removed pending this work are back, in `dashboard_screen.dart`
and `income_list_screen.dart`, reading live off the fields above.

### Local reminders
No package existed for this before — `flutter_local_notifications` +
`timezone` are new (`firebase_messaging`, present but unused, is for
server-sent push and isn't the right tool for a client-scheduled daily
alert). `core/notifications/notification_service.dart` schedules a single
fixed-id daily notification; timezone handling uses a fixed-UTC-offset
`Etc/GMT±N` zone (same simplification `currentUtcOffsetLabel` already makes
elsewhere — no platform-channel timezone package pulled in just for this,
at the cost of not tracking DST). `UserProfile.reminderHour`/`reminderMinute`
persist the setting; `main.dart` re-syncs the OS-level schedule on every
cold start as insurance against a device reboot clearing it (no boot
receiver was added — `POST_NOTIFICATIONS` is the only new Android manifest
permission).

### Dark mode
`buildAppTheme` now takes a `Brightness` and every component theme
(`cardTheme`, `inputDecorationTheme`, etc.) reads from the resolved
`ColorScheme` instead of the `AppColors` constants directly, which is what
makes it theme-aware. Dark palette keeps the app's own terracotta/green
hues, standard M3 dark-theme lightening/darkening rather than a naive
inversion. `MaterialApp.router` follows `ThemeMode.system` — no manual
toggle, so no preferences package needed.

### Firebase App Check
Activated in `main.dart` with debug providers under `kDebugMode` (so local
`flutter run` on an emulator doesn't fail Play Integrity/App Attest
attestation) and Play Integrity/App Attest otherwise. This only makes the
client attach tokens — turning on *enforcement* is a Firebase Console step,
still outstanding.

### Account deletion
`AuthRepository.deleteAccount()` deletes every known subcollection under
`users/{uid}` (paged, batched deletes — the client SDK has no
"delete collection" call), then the profile doc, then the Firebase Auth
user. Firebase requires a recent sign-in for this; a `requires-recent-login`
`FirebaseAuthException` now maps to `ReauthRequiredFailure`, which
`AccountScreen` catches to prompt the matching re-auth flow (password
re-entry or Google) before retrying once.

### CSV import
No file-picker/CSV package existed before — `file_picker` + `csv` are new.
`features/imports/application/import_row.dart` is pure Dart (parses common
date shells, flags — not excludes — likely duplicates by
date+amount+payee) and is unit-tested; `ImportScreen` does pick → map
columns → preview → single-bucket commit via the existing
`ExpenseRepository`/`ExpenseController`.

### Trends + search
`features/trends/` adds a 6-month spend bar chart (`fl_chart`, new
dependency), built from `expensesForMonthProvider` calls already used
elsewhere rather than a new unbounded query. `TransactionsScreen` gained a
payee/note search field and a bucket-filter chip row.

### Two real, pre-existing bugs found once a working toolchain existed
No prior session in this repo had a working Flutter SDK, so `flutter test`
had never actually been run. Fixed once it was: `parseMoney` treated the
last separator as a decimal point even for zero-decimal currencies, so
`"1,200"` UGX parsed as `1` instead of `1200`; `currencyHasSymbol` treated
any letter-only currency abbreviation (`USh`, `CHF`) as a tight-fitting
glyph like `$`, rendering `"USh1,200"` instead of `"USh 1,200"`. Also fixed:
a date-overflow bug in `recurring_payment.dart`'s (formerly
`recurring_repository.dart`'s) monthly/yearly stepping, where a payment due
on the 31st drifted into the following month instead of clamping to the
short month's last day — the stepping logic was pulled out into pure,
directly-testable functions (`stepOccurrence`/`occurrenceDates`/`amountAt`)
as part of the fix.

## Verification

`flutter analyze` clean and `flutter test` green (136 tests, up from 116
before this pass — 20 new: `recurring_payment_test.dart`,
`import_row_test.dart`, `spend_trend_test.dart`, plus one added case in
`plan_vs_actual_test.dart` for the archived-bucket reconciliation fix).
`dart run build_runner build` regenerated for every new/changed `@riverpod`
provider.

**Not verified**: no Firestore emulator is configured in this repo and there
is no test Firebase account available in this environment, so none of the
above was exercised against a live sign-in or real Firestore writes — the
transactional balance/allocation logic, notification scheduling, and account
deletion are all verified by static analysis and pure-Dart unit tests only.
Before shipping, at minimum: manually click through allocate → expense →
delete → restore on a real account and confirm `Bucket.balanceMinor` and
`UserProfile.unallocatedMinor` land where the math above says they should,
and confirm the evening reminder actually fires on a physical device (local
notification scheduling is one of the harder things to get right blind).

## Settings — notes

- Every row is now real except "Plan & billing" (still "Coming soon" —
  FR-15/16 trial/freemium logic is unbuilt).
- Currency is deliberately *not* editable, matching the promise made during
  onboarding.

## Money handling — read this before touching an amount

Amounts are integer **minor units**; decimal places come from the currency,
never a constant. `core/utils/currency.dart` owns the facts
(`currencyDecimals`, `currencySymbol`); `formatMoney`/`core/widgets/money_field.dart`
are the only way to render/enter money. Do not reintroduce `int.tryParse`
on an amount.

## Open questions
- **Q-01**: Enabling App Check *enforcement* (not just client activation) is
  a Firebase Console step, not code — do it before a public beta.
- **Q-02**: `minSdk` uses Flutter's default; confirm whether pre-API-21
  devices need support.
- **Q-03**: Receipt/screenshot capture ADR (`docs/adr-001-receipt-interpretation.md`)
  remains unimplemented and unresolved — unrelated to this pass.
- **Q-04**: A parallel Django/PostgreSQL implementation of overlapping
  functionality exists at the repo root (`ledger/`, `accounts/`,
  `recurring/`), despite `docs/adr-001-stack.md` explicitly rejecting
  Flutter+Firebase as the stack. Which one is the real product needs a
  decision before more work lands on either side.
