import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';

/// Everything that goes into one month's exported statement.
///
/// Pure Dart and free of any PDF types: what the statement *says* is a domain
/// decision, how it is drawn is not. That split is what makes the content
/// testable without rendering a document.
class MonthlyStatement {
  const MonthlyStatement({
    required this.report,
    required this.expenses,
    required this.incomeEvents,
    required this.currency,
    required this.generatedAt,
  });

  final PlanVsActual report;
  final List<Expense> expenses;
  final List<IncomeEvent> incomeEvents;
  final String currency;
  final DateTime generatedAt;

  DateTime get month => report.month;

  /// Oldest first — a statement reads forwards through the month, unlike the
  /// app's activity lists which lead with what just happened.
  List<Expense> get expensesInDateOrder =>
      [...expenses]..sort((a, b) => a.occurredOn.compareTo(b.occurredOn));

  List<IncomeEvent> get incomeInDateOrder =>
      [...incomeEvents]..sort((a, b) => a.occurredOn.compareTo(b.occurredOn));

  String bucketName(String bucketId) {
    for (final line in report.buckets) {
      if (line.bucket.id == bucketId) return line.bucket.name;
    }
    return 'Unassigned';
  }

  /// Bucket lines worth printing: anything planned or spent. Ordered by the
  /// user's own bucket order, since a printed statement is read as a ledger
  /// rather than scanned for the worst offender.
  List<BucketVarianceLine> get bucketLines {
    return [...report.buckets.where((line) => !line.isUntouched)]
      ..sort((a, b) => a.bucket.sortOrder.compareTo(b.bucket.sortOrder));
  }

  int get untouchedBucketCount =>
      report.buckets.where((line) => line.isUntouched).length;

  bool get isEmpty =>
      expenses.isEmpty && incomeEvents.isEmpty && !report.hasPlan;

  String get fileName => 'fintrack-statement-${monthKey(month)}.pdf';
}
