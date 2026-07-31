import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/trends/application/spend_trend.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense(DateTime occurredOn, int amountMinor, {DateTime? deletedAt}) => Expense(
      id: '${occurredOn.millisecondsSinceEpoch}-$amountMinor',
      bucketId: 'groceries',
      amountMinor: amountMinor,
      occurredOn: occurredOn,
      deletedAt: deletedAt,
    );

void main() {
  group('lastMonths', () {
    test('returns the requested count, oldest first, ending at now', () {
      final months = lastMonths(3, now: DateTime(2026, 7, 15));
      expect(months, [DateTime(2026, 5), DateTime(2026, 6), DateTime(2026, 7)]);
    });

    test('crosses a year boundary', () {
      final months = lastMonths(3, now: DateTime(2026, 1, 15));
      expect(months, [DateTime(2025, 11), DateTime(2025, 12), DateTime(2026, 1)]);
    });
  });

  group('buildSpendTrend', () {
    test('sums each month independently', () {
      final months = [DateTime(2026, 6), DateTime(2026, 7)];
      final trend = buildSpendTrend(
        months: months,
        expensesByMonth: [
          [_expense(DateTime(2026, 6, 5), 1000), _expense(DateTime(2026, 6, 20), 500)],
          [_expense(DateTime(2026, 7, 1), 2000)],
        ],
      );
      expect(trend[0].totalMinor, 1500);
      expect(trend[1].totalMinor, 2000);
    });

    test('excludes soft-deleted expenses from the total', () {
      final trend = buildSpendTrend(
        months: [DateTime(2026, 6)],
        expensesByMonth: [
          [
            _expense(DateTime(2026, 6, 5), 1000),
            _expense(DateTime(2026, 6, 6), 500, deletedAt: DateTime(2026, 6, 7)),
          ],
        ],
      );
      expect(trend.single.totalMinor, 1000);
    });

    test('a month with no expenses is zero, not omitted', () {
      final trend = buildSpendTrend(months: [DateTime(2026, 6)], expensesByMonth: [[]]);
      expect(trend.single.totalMinor, 0);
    });
  });
}
