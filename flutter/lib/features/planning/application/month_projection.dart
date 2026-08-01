import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:fintrack/features/recurring/application/recurring_payment.dart';

/// Where the month lands if nothing changes.
///
/// [PlanVsActual.projectedSpendMinor] answers the same question with a single
/// straight line through everything spent so far. That line is wrong in the one
/// case that matters most: rent lands on the 1st, so on the 3rd it forecasts a
/// month of rent every three days. This splits the month into what is already
/// known and what has to be guessed —
///
///   projected spend = spent so far
///                   + recurring charges still due before month end
///                   + everyday spend continuing at its own pace
///
/// — so a fixed obligation is counted exactly once, on its due date, and only
/// discretionary spend is extrapolated.
///
/// Pure Dart: no Firebase, so it is unit-testable without emulators.
class MonthProjection {
  const MonthProjection({
    required this.month,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.hasPlan,
    required this.plannedSpendMinor,
    required this.spentMinor,
    required this.recurringSpentMinor,
    required this.committedMinor,
    required this.expectedIncomeMinor,
    required this.actualIncomeMinor,
  });

  /// Builds the projection for [report]'s month.
  ///
  /// [expenses] must be that month's expenses (the same ones behind [report]) —
  /// they carry the `occurrenceId` that says which spend was a recurring charge
  /// and which was everyday spend.
  ///
  /// A skipped occurrence still counts as committed until its due date passes:
  /// skips live in their own collection, not on the expense, so they aren't
  /// visible here. Over-forecasting a charge the user waved off is the safer
  /// direction to be wrong in.
  factory MonthProjection.from({
    required PlanVsActual report,
    required List<Expense> expenses,
    required List<RecurringPayment> payments,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final monthStart = report.month;
    // Inclusive of the last day: a charge due on the 31st is still this month's
    // money.
    final monthEnd = DateTime(
      monthStart.year,
      monthStart.month,
      report.daysInMonth,
      23,
      59,
      59,
    );
    // Charges already due but not yet confirmed stay in the forecast — an
    // overdue bill is money that still has to leave. For a month that has
    // already ended the window is empty and the projection collapses to
    // actuals.
    final windowStart =
        startOfToday.isAfter(monthStart) ? startOfToday : monthStart;

    final settledOccurrenceIds = {
      for (final expense in expenses)
        if (expense.occurrenceId != null) expense.occurrenceId!,
    };

    var committedMinor = 0;
    for (final payment in payments) {
      for (final dueOn in occurrenceDates(payment, windowStart, monthEnd)) {
        // Confirmed occurrences are already expenses; counting them here as
        // well would double the charge for the rest of the month.
        if (settledOccurrenceIds.contains(occurrenceIdFor(payment.id, dueOn))) {
          continue;
        }
        committedMinor += amountAt(payment, dueOn);
      }
    }

    final recurringSpentMinor = expenses
        .where((expense) => expense.occurrenceId != null)
        .fold<int>(0, (sum, expense) => sum + expense.amountMinor);

    return MonthProjection(
      month: monthStart,
      daysElapsed: report.daysElapsed,
      daysInMonth: report.daysInMonth,
      hasPlan: report.hasPlan,
      plannedSpendMinor: report.spend.plannedMinor,
      spentMinor: report.spend.actualMinor,
      recurringSpentMinor: recurringSpentMinor,
      committedMinor: committedMinor,
      expectedIncomeMinor: report.income.plannedMinor,
      actualIncomeMinor: report.income.actualMinor,
    );
  }

  final DateTime month;
  final int daysElapsed;
  final int daysInMonth;
  final bool hasPlan;
  final int plannedSpendMinor;

  /// Everything spent this month so far, recurring and everyday together.
  final int spentMinor;

  /// The part of [spentMinor] that came from a confirmed recurring occurrence.
  final int recurringSpentMinor;

  /// Recurring charges still to come before the month ends.
  final int committedMinor;

  final int expectedIncomeMinor;
  final int actualIncomeMinor;

  int get daysRemaining => (daysInMonth - daysElapsed).clamp(0, daysInMonth);

  double get monthProgress => daysInMonth > 0 ? daysElapsed / daysInMonth : 0;

  /// Spend that wasn't a fixed obligation — the only part worth extrapolating.
  int get variableSpentMinor => spentMinor - recurringSpentMinor;

  /// Everyday spend for the rest of the month, at the pace set so far.
  int get variableForecastMinor {
    if (daysElapsed <= 0 || daysRemaining <= 0) return 0;
    return (variableSpentMinor / daysElapsed * daysRemaining).round();
  }

  int get projectedSpendMinor =>
      spentMinor + committedMinor + variableForecastMinor;

  /// Income already received wins once it exceeds what was expected: a bonus
  /// that landed is money in hand, not a plan to be revised down to.
  int get projectedIncomeMinor =>
      actualIncomeMinor > expectedIncomeMinor ? actualIncomeMinor : expectedIncomeMinor;

  /// What the month ends with if the projection holds. Negative means the
  /// month is on course to spend more than it takes in.
  int get projectedLeftoverMinor => projectedIncomeMinor - projectedSpendMinor;

  /// Positive means the projection lands over the planned spend.
  int get projectedVsPlanMinor => projectedSpendMinor - plannedSpendMinor;

  /// Whether a run-rate is worth showing yet. Extrapolating everyday spend from
  /// the first two days produces confident nonsense; the committed half of the
  /// projection is exact from day 1 either way.
  bool get runRateIsMeaningful => monthProgress >= 0.25;

  /// Nothing planned, nothing spent and nothing committed — there is no
  /// projection to make.
  bool get isEmpty =>
      !hasPlan && spentMinor == 0 && committedMinor == 0 && expectedIncomeMinor == 0;
}
