import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';

/// How a planned-vs-actual pair is tracking, in ascending order of concern.
///
/// Deliberately not a percentage threshold. A flat "over 85% of plan" warning
/// fires the same on day 5 and day 28, which trains the user to ignore it.
enum VarianceState {
  /// Tracking where it should be for this point in the month.
  onTrack,

  /// Drifting the wrong way against pace, but the month can still land on plan.
  offPace,

  /// The full-month plan is already blown. Spend only — income falling short
  /// mid-month is expected, not a failure, so income never reaches this state.
  offPlan,
}

/// One planned-vs-actual pair.
///
/// [higherIsBetter] carries the sign convention so that income and spend can
/// share one type: spending under plan is good, earning under plan is not. Get
/// this wrong per-widget and the dashboard colours income exactly backwards.
class VarianceLine {
  const VarianceLine({
    required this.label,
    required this.plannedMinor,
    required this.actualMinor,
    required this.higherIsBetter,
    required this.monthProgress,
  });

  final String label;
  final int plannedMinor;
  final int actualMinor;

  /// Whether exceeding the plan is the desirable outcome. True for income,
  /// false for spend.
  final bool higherIsBetter;

  /// Fraction of the month elapsed, 0..1.
  final double monthProgress;

  bool get hasPlan => plannedMinor > 0;

  /// Signed difference from the full-month plan. Positive means above plan,
  /// which is good or bad depending on [higherIsBetter].
  int get varianceMinor => actualMinor - plannedMinor;

  /// Where a straight-line month would put you today.
  ///
  /// Straight-line is wrong for a bucket dominated by a single fixed charge —
  /// rent lands on the 1st and the bucket reads as ahead of pace for the rest
  /// of the month. [state] contains the damage (such a bucket goes [offPace],
  /// never [offPlan], until it genuinely exceeds its plan), which is why pace
  /// is phrased as a neutral fact in the UI and not as a warning. Revisit once
  /// the report is aware of recurring payments.
  int get pacedTargetMinor =>
      (plannedMinor * monthProgress.clamp(0.0, 1.0)).round();

  int get pacedVarianceMinor => actualMinor - pacedTargetMinor;

  /// Fraction of the plan consumed. Left unclamped so callers can detect and
  /// render overflow rather than silently showing a full bar.
  double get actualRatio => hasPlan ? actualMinor / plannedMinor : 0;

  VarianceState get state {
    if (!hasPlan) return VarianceState.onTrack;
    if (higherIsBetter) {
      // Income. Being short of the full-month plan on day 5 is normal, so only
      // pace can distinguish "late" from "not coming".
      if (actualMinor >= plannedMinor) return VarianceState.onTrack;
      return actualMinor < pacedTargetMinor
          ? VarianceState.offPace
          : VarianceState.onTrack;
    }
    if (actualMinor > plannedMinor) return VarianceState.offPlan;
    return actualMinor > pacedTargetMinor
        ? VarianceState.offPace
        : VarianceState.onTrack;
  }
}

/// A single bucket's planned spend against what was actually spent in it.
class BucketVarianceLine {
  const BucketVarianceLine({required this.bucket, required this.line});

  final Bucket bucket;
  final VarianceLine line;

  int get plannedMinor => line.plannedMinor;
  int get actualMinor => line.actualMinor;
  int get varianceMinor => line.varianceMinor;
  VarianceState get state => line.state;

  /// No plan and no spend — nothing to report, so these collapse into a footer
  /// count rather than padding the list.
  bool get isUntouched => plannedMinor == 0 && actualMinor == 0;
}

/// One expected income source against the actual income attributed to it.
class ExpectedIncomeLine {
  const ExpectedIncomeLine({
    required this.label,
    required this.expectedMinor,
    required this.actualMinor,
    this.isUnplanned = false,
  });

  final String label;
  final int expectedMinor;
  final int actualMinor;

  /// The catch-all row for income that matched no expected source.
  final bool isUnplanned;

  bool get hasArrived => actualMinor > 0;
  int get varianceMinor => actualMinor - expectedMinor;
}

/// The whole month's plan-vs-actual picture, assembled from the plan and the
/// actuals. Pure Dart: no Firebase, so it is unit-testable without emulators.
class PlanVsActual {
  const PlanVsActual({
    required this.month,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.plan,
    required this.income,
    required this.spend,
    required this.buckets,
    required this.incomeSources,
  });

  factory PlanVsActual.from({
    required DateTime month,
    required MonthlyPlan plan,
    required List<Bucket> buckets,
    required List<Expense> expenses,
    required List<IncomeEvent> incomeEvents,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final resolvedMonth = normaliseMonth(month);
    final daysInMonth = DateTime(
      resolvedMonth.year,
      resolvedMonth.month + 1,
      0,
    ).day;

    final currentMonth = normaliseMonth(today);
    final int daysElapsed;
    if (resolvedMonth.isAfter(currentMonth)) {
      daysElapsed = 0;
    } else if (resolvedMonth.isBefore(currentMonth)) {
      daysElapsed = daysInMonth;
    } else {
      daysElapsed = today.day.clamp(0, daysInMonth);
    }
    final monthProgress = daysInMonth > 0 ? daysElapsed / daysInMonth : 0.0;

    final actualIncomeMinor = incomeEvents.fold<int>(
      0,
      (sum, event) => sum + event.amountMinor,
    );
    final actualSpendMinor = expenses.fold<int>(
      0,
      (sum, expense) => sum + expense.amountMinor,
    );

    final bucketLines = <BucketVarianceLine>[];
    for (final bucket in buckets) {
      final spentMinor = expenses
          .where((e) => e.bucketId == bucket.id)
          .fold<int>(0, (sum, e) => sum + e.amountMinor);
      bucketLines.add(
        BucketVarianceLine(
          bucket: bucket,
          line: VarianceLine(
            label: bucket.name,
            plannedMinor: plan.plannedForBucket(bucket.id),
            actualMinor: spentMinor,
            higherIsBetter: false,
            monthProgress: monthProgress,
          ),
        ),
      );
    }
    // Biggest miss first. Alphabetical would make the user scan every bucket to
    // find the one that needs attention.
    bucketLines.sort(
      (a, b) => b.varianceMinor.abs().compareTo(a.varianceMinor.abs()),
    );

    return PlanVsActual(
      month: resolvedMonth,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
      plan: plan,
      income: VarianceLine(
        label: 'Money in',
        plannedMinor: plan.expectedIncomeTotalMinor,
        actualMinor: actualIncomeMinor,
        higherIsBetter: true,
        monthProgress: monthProgress,
      ),
      spend: VarianceLine(
        label: 'Money out',
        plannedMinor: plan.plannedSpendTotalMinor,
        actualMinor: actualSpendMinor,
        higherIsBetter: false,
        monthProgress: monthProgress,
      ),
      buckets: bucketLines,
      incomeSources: _matchIncomeSources(plan.expectedIncomes, incomeEvents),
    );
  }

  final DateTime month;
  final int daysElapsed;
  final int daysInMonth;
  final MonthlyPlan plan;
  final VarianceLine income;
  final VarianceLine spend;

  /// Sorted by absolute variance, largest first.
  final List<BucketVarianceLine> buckets;
  final List<ExpectedIncomeLine> incomeSources;

  double get monthProgress => daysInMonth > 0 ? daysElapsed / daysInMonth : 0;

  int get daysRemaining => (daysInMonth - daysElapsed).clamp(0, daysInMonth);

  bool get isCurrentMonth {
    final now = normaliseMonth(DateTime.now());
    return month.year == now.year && month.month == now.month;
  }

  /// The headline number: how much of the month's planned spend is still
  /// available. This is the budgeting question — "can I buy this?" — whereas
  /// [netCashMinor] answers the cash-position question.
  int get leftToSpendMinor => spend.plannedMinor - spend.actualMinor;

  /// Income actually received less money actually spent.
  int get netCashMinor => income.actualMinor - spend.actualMinor;

  /// Straight-line projection of where spend lands at month end.
  int get projectedSpendMinor {
    if (monthProgress <= 0) return 0;
    return (spend.actualMinor / monthProgress).round();
  }

  /// How much the plan itself overcommits: planning to spend more than you
  /// expect to earn is a problem visible on day 1, before a single expense.
  int get plannedOverspendMinor {
    final gap = spend.plannedMinor - income.plannedMinor;
    return gap > 0 ? gap : 0;
  }

  bool get hasPlan => !plan.isEmpty;

  /// Actuals exist for the month even though nothing was planned — the case
  /// where prompting the user to set a plan is worth doing.
  bool get hasActuals => income.actualMinor > 0 || spend.actualMinor > 0;
}

/// Attributes each income event to an expected source by matching
/// [IncomeEvent.source] against [ExpectedIncome.label], case- and
/// whitespace-insensitively. Anything unmatched lands in a single "Unplanned
/// income" row rather than being dropped — the totals must always reconcile.
List<ExpectedIncomeLine> _matchIncomeSources(
  List<ExpectedIncome> expected,
  List<IncomeEvent> events,
) {
  String key(String value) => value.trim().toLowerCase();

  final actualBySource = <String, int>{};
  for (final event in events) {
    actualBySource.update(
      key(event.source),
      (value) => value + event.amountMinor,
      ifAbsent: () => event.amountMinor,
    );
  }

  final sorted = [...expected]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final lines = <ExpectedIncomeLine>[];
  for (final source in sorted) {
    final matched = actualBySource.remove(key(source.label)) ?? 0;
    lines.add(
      ExpectedIncomeLine(
        label: source.label,
        expectedMinor: source.amountMinor,
        actualMinor: matched,
      ),
    );
  }

  final unplannedMinor = actualBySource.values.fold<int>(0, (a, b) => a + b);
  if (unplannedMinor > 0) {
    lines.add(
      ExpectedIncomeLine(
        label: 'Unplanned income',
        expectedMinor: 0,
        actualMinor: unplannedMinor,
        isUnplanned: true,
      ),
    );
  }
  return lines;
}
