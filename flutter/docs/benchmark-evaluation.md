# FinTrack vs. entry-level budgeting apps — functional evaluation
_Assessed 2026-07-31 against `lib/` at `claude/flutter-budgeting-benchmarks-bmgbjp`._

## What this measures

"Entry-level budgeting app utility" here means the functional bar a **manual-entry**
budgeting app has to clear before a normal person keeps using it past week two.
The comparison class is the manual/envelope tier — EveryDollar (free), Goodbudget,
Wallet by BudgetBakers, Spendee, YNAB's core loop — not bank-aggregation products
like Monarch or Copilot. Bank sync is therefore *not* treated as table stakes;
CSV import, transaction editing and reminders are, because every app in that class
ships them.

Scores are against that bar, not against a hypothetical finished FinTrack.

## Scorecard

| # | Dimension | Score | One-line verdict |
|---|-----------|:-----:|------------------|
| 1 | Onboarding & time-to-first-value | 3.0 / 5 | Currency setup is best-in-class; nothing seeds a first budget. |
| 2 | Expense capture speed | 4.0 / 5 | Meets the ≤4-tap bar with a genuinely good amount field. |
| 3 | Correction & data integrity | **1.5 / 5** | You cannot edit anything. Income cannot even be deleted. |
| 4 | Budget model completeness | 2.5 / 5 | Excellent variance reporting on top of a missing envelope engine. |
| 5 | Recurring & bills | 3.0 / 5 | Registry and confirm→expense work; no edit, no reminders, date-drift bug. |
| 6 | Awareness loop | 2.5 / 5 | Strong in-app dashboard, zero out-of-app signal. |
| 7 | Reporting & insight | 3.0 / 5 | PDF statement and earnings report beat the bar; no trends at all. |
| 8 | Getting existing data in | 1.0 / 5 | No import of any kind. |
| 9 | Trust, security, compliance | 2.0 / 5 | Rules are right; App Check inert, no app lock, no account deletion. |
| 10 | Platform polish | 2.5 / 5 | Light theme only, English only, unbounded queries. |
| 11 | Retention mechanics | 0.5 / 5 | No reminders, no recap, no analytics instrumented. |
| 12 | Monetization | 0.0 / 5 | Specified, not built. |

**Weighted read: ~2.4 / 5 — roughly half of an entry-level utility bar.**

The shape is unusual and worth naming: this is not an evenly half-finished app. A
few pieces are *above* the benchmark class (multi-currency money handling,
pace-adjusted variance, PDF statements), sitting next to holes that a mainstream
app would treat as launch blockers (can't fix a typo, can't allocate income).

## Where it beats the benchmark

- **Money handling** (`core/utils/currency.dart`, `core/widgets/money_field.dart`).
  Integer minor units with per-currency exponents — 0 for UGX/JPY, 3 for KWD — and
  a cash-register entry widget where no keystroke can produce an unparseable
  value. Most apps in this tier hardcode two decimals and quietly break outside
  the US/EU. This is genuinely better than the class.
- **Pace-adjusted variance** (`features/planning/application/plan_vs_actual.dart`).
  A three-state ladder (on track / off pace / off plan) with a straight-line pace
  tick, instead of the usual "you've used 85% of Groceries" alert that fires
  identically on day 5 and day 28. The sign convention (`higherIsBetter`) so income
  and spend share one type is the correct design. Well tested — 449 lines.
- **Per-month plan snapshots** (`monthlyPlans/{YYYY-MM}`). Editing a bucket today
  does not rewrite what you planned last March. Goodbudget and EveryDollar both
  get this right; plenty of smaller apps do not.
- **PDF statement export** (`features/reports/`) and the **gross-vs-take-home
  earnings report** (`features/earnings/`). Both are above the entry-level bar —
  the deduction-rate report in particular has no equivalent in the comparison set.
- **Undo instead of confirm dialogs.** Soft deletes make Undo a field flip, so a
  swipe acts immediately. Correct instinct.

## Blocking gaps (P0 — the app is not entry-level useful without these)

### 1. Nothing can be edited
`ExpenseRepository` exposes add / delete / restore and no update.
`IncomeRepository` exposes **only** `watch` and `add` — a mistyped paycheque is
permanent and unremovable. `RecurringRepository` has no update or delete either;
`income_list_screen.dart` has no tap target, no dismissible, nothing.

Every app in the comparison class lets you tap a transaction and change amount,
category, date and note. This is the single largest deviation from the benchmark,
and it is the kind that ends usage in week one: the first fat-fingered `12500`
poisons the month's numbers with no recourse.

**Needs:** `updateExpense`, full income CRUD, recurring edit/delete, and a tap
target on every list row.

### 2. Income is never allocated — the stated premise is unimplemented
The README describes FinTrack as "allocate incoming money into buckets". FR-08
(allocation), FR-09 (unallocated funds) and carry-over balances are all absent, and
the dashboard had to *remove* the unallocated banner and goal-progress percentage
rather than show hardcoded zeros (see `implementation-status.md`).

What ships is a **planned-spend-vs-actual-spend tracker**, not an envelope system.
Concretely it means: buckets have no balance, money in and money out are two
unconnected columns, goals show a target with no progress, and unspent Groceries
money in July does not exist in August. Goodbudget's free tier — the closest
comparable — is built entirely on the envelope balance and rollover this lacks.

**Needs:** allocation of an income event across buckets, a derived bucket balance,
month-end carry-over, and the unallocated-funds surface back on the dashboard.

### 3. No out-of-app signal whatsoever
`firebase_messaging` is a dependency. It is never imported outside `pubspec.yaml`.
There is no evening reminder (Settings shows it disabled, "Coming soon"), no
bill-due alert, no overspend alert, no weekly recap. Daily-logging apps live or die
on the reminder — it is the highest-leverage retention feature in the category and
it is 100% absent.

`firebase_analytics` is likewise dead weight, which means activation and retention
cannot currently be *measured* either.

### 4. Deleting a bucket corrupts the month
`BucketRepository.deleteBucket` hard-deletes the document. Expenses and recurring
payments keep the dead `bucketId`. Consequences, all live today:

- The dashboard renders those rows as "Unknown bucket".
- `PlanVsActual` sums `actualSpendMinor` over *all* expenses but builds bucket lines
  only for surviving buckets — so the per-bucket rows stop reconciling with the
  month total, silently.
- Confirming a recurring occurrence whose bucket was deleted writes a new expense
  into a nonexistent bucket, indefinitely.

Compare: the benchmark behaviour is either a soft archive, or delete-with-reassign
("move 14 transactions to…"). Bucket deletion currently has a confirmation dialog
but no data safety behind it.

## Real defects found while reading

| Where | Defect |
|---|---|
| `recurring_repository.dart` `_step` | `DateTime(from.year, from.month + 1, from.day)` overflows for short months: a payment due the 31st steps to 31 Feb → 3 March, and every subsequent occurrence inherits the drift. Rent and salary dates are exactly the ones that land on 29–31. |
| `expense_repository.dart` `recentExpenses` | Unbounded `watchExpenses()` on a `keepAlive` provider, streaming the user's entire expense history to render five dashboard rows. No `.limit()`. Firestore read cost and memory grow linearly forever. |
| `recurring_repository.dart` `_occurrenceDates` | Iterates from `payment.startOn` to the window end on every snapshot. A daily payment started three years ago is ~1,100 loop steps per payment per recomputation. |
| `main.dart` | `firebase_app_check` is a dependency but `FirebaseAppCheck.instance.activate()` is never called — the declared protection on Firestore and Functions is not in force. |
| `pubspec.yaml` | `firebase_messaging`, `firebase_analytics`, `firebase_remote_config` ship in the binary and are never initialized. |
| `test/widget_test.dart` | Placeholder `expect(true, isTrue)`. All 1,176 lines of tests are pure-domain; there is zero widget or integration coverage — no test asserts that any screen builds. |
| `docs/implementation-status.md` | Stale. FR-01, FR-02 and US-10 are marked "Not started" but sign-up, email verification and occurrence confirm/skip are all implemented and wired. |

## Secondary gaps (P1)

- **No dark mode.** `buildAppTheme()` is `Brightness.light` only and `MaterialApp`
  sets no `darkTheme` — despite a `dark.html` mockup sitting in the repo root.
  Table stakes for a 2026 consumer app.
- **No CSV import.** Disabled row in Settings. Users arriving with a spreadsheet
  cannot bring history in, which caps the app's first-session value at zero.
- **No account deletion.** Required by both Play and App Store policy for accounts
  created in-app, and by GDPR/erasure requests. `account_screen.dart` offers sign-out
  only. This blocks store submission, not just parity.
- **No app lock / biometrics.** Standard in the finance category; absent.
- **No search or filter** on transactions — month picker only. Finding "that
  restaurant charge" requires scrolling.
- **English-only.** Every string is hardcoded; no `intl`, no ARB, no `l10n`. Ironic
  given how carefully the currency layer handles 100+ countries — the app can format
  UGX correctly and then only ever say "Add Expense" in English.
- **No offline/sync-state UI.** Firestore's mobile persistence is on by default so
  writes queue, but nothing tells the user that, and nothing distinguishes "saved"
  from "saved locally, not yet synced".

## Nice-to-have (P2)

Trend charts (spend over time, category share over months — currently zero
time-series visualization anywhere), home-screen quick-add widget, payee
autocomplete from history, receipt capture (ADR-001 exists, unbuilt), shared/joint
budgets, freemium gate and trial (FR-15/FR-16, specified only).

## Recommended sequence to reach the bar

1. **Editing everywhere** — `updateExpense`, income CRUD, recurring edit/delete.
   Smallest change, largest correctness win, unblocks daily use.
2. **Bucket delete safety** — soft archive or reassign-on-delete. Cheap, stops
   active data corruption.
3. **Allocation + carry-over (FR-08/09)** — makes the app the thing its README
   claims, and unlocks goal progress and the unallocated banner already designed for.
4. **Local notifications: evening reminder + bill due** — the retention lever.
5. **Dark mode, App Check activation, account deletion** — three small, independent
   items; the latter two are store/compliance blockers.
6. **CSV import** — removes the cold-start wall.
7. **Trends + search** — depth for retained users.

Steps 1–4 are what move this from "impressive skeleton" to "an entry-level
budgeting app someone would actually keep".

## Verification note

`flutter analyze` and `flutter test` were **not** run — no Flutter SDK is available
in this environment. Every finding above comes from reading `lib/`, `test/`,
`firestore.rules` and `pubspec.yaml` directly. The defect table should be confirmed
against a real toolchain before being worked.
