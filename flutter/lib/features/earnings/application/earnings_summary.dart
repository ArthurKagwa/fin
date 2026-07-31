import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';

/// One deduction line rolled up across a month — several paycheques with a
/// "PAYE" line each become a single PAYE total.
class DeductionTotal {
  const DeductionTotal({required this.label, required this.amountMinor});

  final String label;
  final int amountMinor;
}

/// What one month actually earned, before and after deductions.
class EarningsMonth {
  const EarningsMonth({
    required this.month,
    required this.grossMinor,
    required this.deductionsMinor,
    required this.takeHomeMinor,
    required this.deductions,
    required this.paychequeCount,
  });

  final DateTime month;
  final int grossMinor;
  final int deductionsMinor;
  final int takeHomeMinor;

  /// Largest deduction first — the one worth understanding.
  final List<DeductionTotal> deductions;
  final int paychequeCount;

  /// The share of gross that never reached the user. This, rather than either
  /// raw total, is the number that answers "where does my salary go?".
  double get deductionRate => grossMinor > 0 ? deductionsMinor / grossMinor : 0;

  bool get hasDeductions => deductionsMinor > 0;
}

/// Gross vs take-home over time (US-23).
class EarningsSummary {
  const EarningsSummary({required this.months});

  /// Newest month first.
  factory EarningsSummary.from(List<IncomeEvent> events) {
    final byMonth = <DateTime, List<IncomeEvent>>{};
    for (final event in events) {
      byMonth
          .putIfAbsent(normaliseMonth(event.occurredOn), () => [])
          .add(event);
    }

    final months = byMonth.entries.map((entry) {
      var grossMinor = 0;
      var deductionsMinor = 0;
      var takeHomeMinor = 0;
      var paychequeCount = 0;
      final deductionsByLabel = <String, int>{};

      for (final event in entry.value) {
        // Non-paycheque income has nothing withheld, so its gross is simply the
        // amount received. Treating it as zero-gross would understate the month
        // and skew the deduction rate.
        grossMinor += event.grossMinor ?? event.amountMinor;
        takeHomeMinor += event.amountMinor;
        deductionsMinor += event.deductionsTotalMinor;
        if (event.isPaycheque) paychequeCount++;
        for (final deduction in event.deductions) {
          deductionsByLabel.update(
            deduction.label,
            (value) => value + deduction.amountMinor,
            ifAbsent: () => deduction.amountMinor,
          );
        }
      }

      final deductions = deductionsByLabel.entries
          .map((e) => DeductionTotal(label: e.key, amountMinor: e.value))
          .toList()
        ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

      return EarningsMonth(
        month: entry.key,
        grossMinor: grossMinor,
        deductionsMinor: deductionsMinor,
        takeHomeMinor: takeHomeMinor,
        deductions: deductions,
        paychequeCount: paychequeCount,
      );
    }).toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    return EarningsSummary(months: months);
  }

  final List<EarningsMonth> months;

  bool get isEmpty => months.isEmpty;

  int get grossTotalMinor =>
      months.fold(0, (sum, m) => sum + m.grossMinor);

  int get deductionsTotalMinor =>
      months.fold(0, (sum, m) => sum + m.deductionsMinor);

  int get takeHomeTotalMinor =>
      months.fold(0, (sum, m) => sum + m.takeHomeMinor);

  /// Weighted by gross rather than averaged across months, so a month with one
  /// small payment can't drag the headline rate around.
  double get effectiveDeductionRate =>
      grossTotalMinor > 0 ? deductionsTotalMinor / grossTotalMinor : 0;

  /// Deduction totals rolled up across every month, largest first.
  List<DeductionTotal> get deductionsAcrossAllMonths {
    final totals = <String, int>{};
    for (final month in months) {
      for (final deduction in month.deductions) {
        totals.update(
          deduction.label,
          (value) => value + deduction.amountMinor,
          ifAbsent: () => deduction.amountMinor,
        );
      }
    }
    return totals.entries
        .map((e) => DeductionTotal(label: e.key, amountMinor: e.value))
        .toList()
      ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
  }

  /// Take-home change from the previous month to the newest one. Null when
  /// there isn't a previous month to compare against.
  int? get takeHomeChangeMinor {
    if (months.length < 2) return null;
    return months[0].takeHomeMinor - months[1].takeHomeMinor;
  }

  EarningsSummary limitedTo(int monthCount) =>
      EarningsSummary(months: months.take(monthCount).toList());
}
