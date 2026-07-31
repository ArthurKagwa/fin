import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:fintrack/features/reports/application/monthly_statement.dart';
import 'package:flutter_test/flutter_test.dart';

final _july = DateTime(2026, 7);

Bucket _bucket(String id, {required int sortOrder, String? name}) =>
    Bucket(id: id, name: name ?? id, sortOrder: sortOrder);

Expense _expense(String bucketId, int amount, int day, {String? payee}) =>
    Expense(
      id: '$bucketId-$day-$amount',
      bucketId: bucketId,
      amountMinor: amount,
      occurredOn: DateTime(2026, 7, day),
      payee: payee,
    );

IncomeEvent _income(String source, int amount, int day) => IncomeEvent(
      id: '$source-$day',
      kind: IncomeKind.other,
      amountMinor: amount,
      occurredOn: DateTime(2026, 7, day),
      source: source,
    );

MonthlyStatement _statement({
  List<Bucket> buckets = const [],
  List<Expense> expenses = const [],
  List<IncomeEvent> incomeEvents = const [],
  Map<String, int> bucketPlans = const {},
  bool isSnapshot = true,
}) {
  final report = PlanVsActual.from(
    month: _july,
    plan: MonthlyPlan(
      month: _july,
      expectedIncomes: const [],
      bucketPlans: bucketPlans,
      isSnapshot: isSnapshot,
    ),
    buckets: buckets,
    expenses: expenses,
    incomeEvents: incomeEvents,
    now: DateTime(2026, 7, 20),
  );
  return MonthlyStatement(
    report: report,
    expenses: expenses,
    incomeEvents: incomeEvents,
    currency: 'UGX',
    generatedAt: DateTime(2026, 7, 20, 9, 30),
  );
}

void main() {
  group('bucket lines', () {
    test('are in the user\'s own order, not ranked by variance', () {
      // The report ranks by biggest miss; a printed statement is read as a
      // ledger, so it follows the order the user arranged their buckets in.
      final statement = _statement(
        buckets: [
          _bucket('rent', sortOrder: 0),
          _bucket('food', sortOrder: 1),
          _bucket('fun', sortOrder: 2),
        ],
        bucketPlans: const {'rent': 1000, 'food': 1000, 'fun': 1000},
        expenses: [
          _expense('fun', 5000, 3),
          _expense('food', 1010, 4),
          _expense('rent', 1000, 1),
        ],
      );
      expect(
        statement.bucketLines.map((l) => l.bucket.id).toList(),
        ['rent', 'food', 'fun'],
      );
    });

    test('exclude buckets with no plan and no spend, but count them', () {
      final statement = _statement(
        buckets: [
          _bucket('used', sortOrder: 0),
          _bucket('idle', sortOrder: 1),
          _bucket('alsoIdle', sortOrder: 2),
        ],
        bucketPlans: const {'used': 500},
      );
      expect(statement.bucketLines.map((l) => l.bucket.id).toList(), ['used']);
      expect(statement.untouchedBucketCount, 2);
    });

    test('a bucket with spend but no plan is still printed', () {
      final statement = _statement(
        buckets: [_bucket('impulse', sortOrder: 0)],
        expenses: [_expense('impulse', 900, 12)],
      );
      expect(statement.bucketLines, hasLength(1));
      expect(statement.untouchedBucketCount, 0);
    });
  });

  group('ordering', () {
    test('transactions read forwards through the month', () {
      final statement = _statement(
        buckets: [_bucket('food', sortOrder: 0)],
        expenses: [
          _expense('food', 100, 20),
          _expense('food', 100, 2),
          _expense('food', 100, 11),
        ],
      );
      expect(
        statement.expensesInDateOrder.map((e) => e.occurredOn.day).toList(),
        [2, 11, 20],
      );
    });

    test('income reads forwards too', () {
      final statement = _statement(
        incomeEvents: [_income('Late', 100, 28), _income('Early', 100, 3)],
      );
      expect(
        statement.incomeInDateOrder.map((e) => e.source).toList(),
        ['Early', 'Late'],
      );
    });

    test('ordering does not mutate the original list', () {
      final expenses = [_expense('food', 100, 20), _expense('food', 100, 2)];
      final statement = _statement(
        buckets: [_bucket('food', sortOrder: 0)],
        expenses: expenses,
      );
      statement.expensesInDateOrder;
      expect(expenses.first.occurredOn.day, 20);
    });
  });

  group('bucket names', () {
    test('resolves a bucket id to its name', () {
      final statement = _statement(
        buckets: [_bucket('b1', sortOrder: 0, name: 'Groceries')],
        bucketPlans: const {'b1': 100},
      );
      expect(statement.bucketName('b1'), 'Groceries');
    });

    test('falls back rather than crashing on a deleted bucket', () {
      // Deleting a bucket keeps its expenses (see bucket_detail_screen), so a
      // statement must still render rows pointing at a bucket that is gone.
      final statement = _statement();
      expect(statement.bucketName('deleted-id'), 'Unassigned');
    });
  });

  test('file name is stable and sorts chronologically', () {
    expect(_statement().fileName, 'fintrack-statement-2026-07.pdf');
  });

  group('emptiness', () {
    test('a month with nothing recorded is empty', () {
      expect(_statement().isEmpty, isTrue);
    });

    test('a month with only a plan is not empty', () {
      final statement = _statement(
        buckets: [_bucket('food', sortOrder: 0)],
        bucketPlans: const {'food': 500},
      );
      expect(statement.isEmpty, isFalse);
    });

    test('a month with only actuals is not empty', () {
      final statement = _statement(incomeEvents: [_income('Gift', 200, 5)]);
      expect(statement.isEmpty, isFalse);
    });
  });

  test('carries the unsnapshotted flag through for the disclaimer', () {
    expect(_statement(isSnapshot: false).report.plan.isSnapshot, isFalse);
    expect(_statement().report.plan.isSnapshot, isTrue);
  });
}
