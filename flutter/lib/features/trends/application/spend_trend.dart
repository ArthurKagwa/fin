import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart' show normaliseMonth;

/// Total spend for one month — one bar in the trend chart. Pure Dart: built
/// from expense lists the screen already has to fetch anyway, not a new
/// Firestore query shape.
class MonthlySpend {
  const MonthlySpend({required this.month, required this.totalMinor});

  final DateTime month;
  final int totalMinor;
}

/// Rolls [expensesByMonth] (one list per requested month, same order as
/// [months]) into a per-month total, skipping soft-deleted entries.
List<MonthlySpend> buildSpendTrend({
  required List<DateTime> months,
  required List<List<Expense>> expensesByMonth,
}) {
  assert(months.length == expensesByMonth.length);
  return [
    for (var i = 0; i < months.length; i++)
      MonthlySpend(
        month: normaliseMonth(months[i]),
        totalMinor: expensesByMonth[i]
            .where((e) => !e.isDeleted)
            .fold<int>(0, (sum, e) => sum + e.amountMinor),
      ),
  ];
}

/// The last [count] months, oldest first, ending with the month containing
/// [now].
List<DateTime> lastMonths(int count, {required DateTime now}) {
  final current = normaliseMonth(now);
  return [
    for (var i = count - 1; i >= 0; i--) DateTime(current.year, current.month - i),
  ];
}
