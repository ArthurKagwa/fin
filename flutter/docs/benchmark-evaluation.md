# FinTrack vs. entry-level budgeting apps — re-evaluation
_Assessed 2026-07-31, after the P0/P1 remediation pass described in
`implementation-status.md`. Baseline: the original evaluation on `main`
before that pass, preserved in git history._

## What this measures (unchanged from the original)

Same comparison class as before: manual-entry envelope budgeting apps
(Goodbudget, EveryDollar, Wallet, Spendee) — not bank-aggregation products.
Same 12 dimensions, same scoring philosophy: scored against what that class
ships as table stakes, not against a hypothetical finished FinTrack.

## Scorecard — before → after

| # | Dimension | Before | After | What changed |
|---|-----------|:---:|:---:|---|
| 1 | Onboarding & time-to-first-value | 3.0 | 3.0 | Untouched this pass — still nothing seeds a first budget |
| 2 | Expense capture speed | 4.0 | 4.0 | Still meets the ≤4-tap bar; editing existing entries doesn't slow the fast path |
| 3 | Correction & data integrity | **1.5** | **4.5** | Full edit/delete/restore for expenses, income, and recurring payments, with Undo everywhere and safety guards (can't edit an allocated income event or hard-delete a referenced bucket) |
| 4 | Budget model completeness | 2.5 | **4.0** | The envelope engine that was missing now exists: real allocation, running bucket balances, true rollover, an unallocated pool |
| 5 | Recurring & bills | 3.0 | 4.0 | Edit, amount-change history, stop-vs-delete safety, Custom interval, and the date-drift bug are all fixed |
| 6 | Awareness loop | 2.5 | 3.5 | The evening reminder — the retention lever the original doc called out as the single highest-leverage gap — now exists |
| 7 | Reporting & insight | 3.0 | 3.5 | Added a 6-month spend trend chart on top of the existing PDF/earnings report |
| 8 | Getting existing data in | **1.0** | **4.0** | CSV import: pick, map columns, preview with duplicates flagged, commit |
| 9 | Trust, security, compliance | 2.0 | 3.5 | App Check activated (client-side); account deletion built. App-lock/biometrics still absent |
| 10 | Platform polish | 2.5 | 3.5 | Dark mode added; the unbounded-query defect fixed. Still English-only |
| 11 | Retention mechanics | **0.5** | 2.0 | One reminder exists now; still no recap, still no analytics instrumented (`firebase_analytics` remains an unused dependency) |
| 12 | Monetization | 0.0 | 0.0 | Out of scope this pass — trial/freemium is still spec-only |

**Directional read: every dimension the original doc scored below 3/5 for a
missing *mechanic* (not a missing *polish item*) moved by a full point or
more.** The three lowest scores in the original — correction (1.5),
getting data in (1.0), retention (0.5) — are the three with the largest
jumps, because they were the three the original doc's own recommended
sequence named first.

A precise before/after single-number comparison isn't reproducible: the
original's "~2.4/5 weighted read" used per-dimension weights that aren't
recorded anywhere, only the score column. An equal-weight average of the
same 12 numbers moves from ~2.1 to ~3.3 — treat that as roughly indicative,
and the per-dimension table above as the reliable comparison.

## What closed, with the receipts

- **Nothing could be edited** → `ExpenseRepository.updateExpense`,
  `IncomeRepository.updateIncomeEvent`/`deleteIncomeEvent`/`restoreIncomeEvent`,
  `RecurringRepository.updateDetails`/`addRatePeriod`/`setEndDate` all now
  exist, wired to real UI (tap-to-edit on every list row, swipe-to-delete
  with Undo on expenses and income).
- **Income was never allocated** → `features/allocations/` is a new
  collection (`users/{uid}/allocations`), `Bucket.balanceMinor` and
  `UserProfile.unallocatedMinor` are new running totals maintained inside
  Firestore transactions at every write path that moves money (add expense,
  delete/restore/edit expense, confirm a recurring occurrence, allocate).
  The dashboard's unallocated banner and goal-progress percentage — removed
  in the prior pass specifically because this didn't exist — are back and
  reading real data.
- **No out-of-app signal** → `flutter_local_notifications` + `timezone`
  are new dependencies; a daily evening reminder is schedulable from
  Settings and re-syncs on every cold start.
- **Deleting a bucket corrupted the month** → `Bucket.archivedAt` came back;
  `BucketRepository.hasReferences` blocks hard-delete once a bucket has any
  expense/recurring/allocation pointing at it, forcing archive instead.
  `PlanRepository.watchPlanVsActual` now sources from `watchAllBuckets()`
  rather than `watchActiveBuckets()`, which is the actual line-level fix for
  the reconciliation bug the last evaluation traced — confirmed by a new
  test case in `plan_vs_actual_test.dart`.
- **The recurring date-overflow bug** (a payment due the 31st drifting into
  March) is fixed and directly unit-tested — the stepping logic was pulled
  out of the Firestore repository into pure, testable functions.
- **The unbounded `recentExpenses` query** now has a `.limit(20)`.
- **App Check was inert** → activated in `main.dart` (debug providers under
  `kDebugMode`, Play Integrity/App Attest otherwise). Enforcement itself is
  a Console step, not code, and remains outstanding.
- **No account deletion** → built, including the reauth flow Firebase Auth
  requires for a session older than its "recent sign-in" window.
- **No CSV import** → built, with duplicate-flagging (not exclusion) per
  the original FR-14 language.
- **Light-theme only** → dark mode, keeping the app's own brand hues rather
  than a generic palette.
- **`implementation-status.md` was stale** → rewritten; the previous
  evaluation's staleness finding (FR-01/02/04/05, US-10 wrongly marked "Not
  started") is fixed as of this pass.

## Two more real bugs found, same way as last time

Static reading plus this pass's actual `flutter analyze`/`flutter test` run
(the prior evaluation's own verification note said neither had been run — a
working toolchain is available in this environment and was used throughout)
turned up two pre-existing, untested money bugs, now fixed:
`parseMoney` misparsed grouped zero-decimal-currency input (`"1,200"` UGX
read as `1`), and `currencyHasSymbol` rendered letter-abbreviation symbols
(`USh`, `CHF`) with no space, contradicting the currency layer's own stated
design intent. Both are covered by `test/money_test.dart`, which failed
before the fix and passes now.

## What's still open (P1/P2, unchanged or newly visible)

- **No de-allocate.** Allocating is one-directional; "I over-allocated, put
  it back" has no UI or repository method yet.
- **Allocation caps against the global unallocated pool, not the specific
  income event's own contribution** — a deliberate simplification (matches
  YNAB/Goodbudget's fungible "ready to assign" model) but worth knowing:
  opening the Allocate sheet from paycheque A can spend money that actually
  arrived from paycheque B.
- **CSV import is single-bucket-per-import** — no per-row category mapping,
  no remembered column mapping across imports.
- **No app lock / biometrics.** Still absent, still standard in the
  finance category.
- **English-only.** No `intl`/ARB/`l10n` — unchanged from the prior finding.
- **`firebase_analytics` is still an unused dependency.** Activation and
  retention still can't be measured even though the retention lever
  (the reminder) now exists.
- **Only one reminder type.** The evening log-your-day nudge exists; there's
  still no bill-due alert or overspend push, both mentioned in the original
  doc's "highest-leverage retention feature" framing.
- **Freemium/trial/billing is entirely unbuilt** — explicitly out of scope
  for this pass, same as the original evaluation found.
- **Zero widget/integration test coverage remains.** This pass added 20 new
  pure-Dart unit tests (136 total, up from 116) covering every new piece of
  testable logic, but `test/widget_test.dart` is still the placeholder —
  nothing asserts that any screen actually builds.
- **Nothing here was verified against a live Firestore/Auth account.** No
  emulator is configured in this repo and no test account is available in
  this environment. The transactional balance math, notification scheduling,
  and account-deletion flow are verified by static analysis and unit tests
  only — see `implementation-status.md`'s verification section for the
  specific manual click-through this still needs before shipping.
- **The parallel Django/PostgreSQL implementation at the repo root**
  (`ledger/`, `accounts/`, `recurring/`) is untouched by this pass and the
  stack-choice conflict with `docs/adr-001-stack.md` is unresolved — still
  worth a decision before more work lands on either side.

## Recommended next sequence

1. **Manual verification pass** against a real Firebase project — the one
   thing this pass genuinely could not do in this environment. Allocate →
   spend → delete → restore, on a real account, watching `balanceMinor`/
   `unallocatedMinor` the whole way.
2. **De-allocate** — the natural next ask once allocation exists at all.
3. **Wire `firebase_analytics`** now that there's a retention feature worth
   measuring the effect of.
4. **App lock / biometrics, then l10n** — the remaining P1 polish items.
5. **Trial/freemium (FR-15/16)** — the only major PRD area with zero
   implementation, deliberately last because monetizing before the product
   loop is solid is the "classic error" the original PRD itself warned
   against.

## Verification note

`flutter analyze` and `flutter test` **were** run this time (136 tests,
0 failures) — the toolchain is available in this environment, unlike when
the prior evaluation and the feature work before it were written. What
was **not** run: anything requiring a live Firebase project (a real sign-in,
a real Firestore write, an actual scheduled OS notification firing, an
actual account deletion). Every claim about transactional correctness above
is a claim about what the code says it will do, verified by reading and by
unit-testing the pure logic underneath it — not a claim that it has been
watched happen against production infrastructure.
