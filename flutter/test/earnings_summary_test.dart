import 'package:fintrack/features/earnings/application/earnings_summary.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:flutter_test/flutter_test.dart';

IncomeEvent _paycheque({
  required DateTime on,
  required int gross,
  required List<({String label, int amount})> deductions,
  String source = 'Salary',
}) {
  final total = deductions.fold<int>(0, (sum, d) => sum + d.amount);
  return IncomeEvent(
    id: '$source-${on.millisecondsSinceEpoch}',
    kind: IncomeKind.paycheque,
    amountMinor: gross - total,
    occurredOn: on,
    source: source,
    grossMinor: gross,
    deductions: [
      for (var i = 0; i < deductions.length; i++)
        Deduction(
          id: '$i',
          label: deductions[i].label,
          amountMinor: deductions[i].amount,
          sortOrder: i,
        ),
    ],
  );
}

IncomeEvent _other({
  required DateTime on,
  required int amount,
  String source = 'Gift',
}) =>
    IncomeEvent(
      id: '$source-${on.millisecondsSinceEpoch}-$amount',
      kind: IncomeKind.other,
      amountMinor: amount,
      occurredOn: on,
      source: source,
    );

void main() {
  group('grouping', () {
    test('rolls events up by month, newest first', () {
      final summary = EarningsSummary.from([
        _other(on: DateTime(2026, 5, 3), amount: 100),
        _other(on: DateTime(2026, 7, 9), amount: 300),
        _other(on: DateTime(2026, 6, 21), amount: 200),
      ]);
      expect(
        summary.months.map((m) => m.month).toList(),
        [DateTime(2026, 7), DateTime(2026, 6), DateTime(2026, 5)],
      );
    });

    test('several events in one month become one row', () {
      final summary = EarningsSummary.from([
        _other(on: DateTime(2026, 7, 1), amount: 100),
        _other(on: DateTime(2026, 7, 28), amount: 250),
      ]);
      expect(summary.months, hasLength(1));
      expect(summary.months.single.takeHomeMinor, 350);
    });

    test('an empty ledger produces an empty summary, not a zero row', () {
      final summary = EarningsSummary.from([]);
      expect(summary.isEmpty, isTrue);
      expect(summary.months, isEmpty);
      expect(summary.effectiveDeductionRate, 0);
    });
  });

  group('gross vs take-home', () {
    test('a paycheque splits into gross, deductions and take-home', () {
      final summary = EarningsSummary.from([
        _paycheque(
          on: DateTime(2026, 7, 25),
          gross: 3000,
          deductions: [(label: 'PAYE', amount: 600), (label: 'NSSF', amount: 300)],
        ),
      ]);
      final month = summary.months.single;
      expect(month.grossMinor, 3000);
      expect(month.deductionsMinor, 900);
      expect(month.takeHomeMinor, 2100);
      expect(month.deductionRate, closeTo(0.3, 1e-9));
      expect(month.paychequeCount, 1);
    });

    test('non-paycheque income counts fully as gross', () {
      // Nothing was withheld from a gift, so treating its gross as zero would
      // understate the month and inflate the deduction rate.
      final summary = EarningsSummary.from([
        _other(on: DateTime(2026, 7, 4), amount: 500),
      ]);
      final month = summary.months.single;
      expect(month.grossMinor, 500);
      expect(month.takeHomeMinor, 500);
      expect(month.deductionsMinor, 0);
      expect(month.deductionRate, 0);
      expect(month.hasDeductions, isFalse);
    });

    test('gross always reconciles to take-home plus deductions', () {
      final summary = EarningsSummary.from([
        _paycheque(
          on: DateTime(2026, 7, 25),
          gross: 3000,
          deductions: [(label: 'PAYE', amount: 600)],
        ),
        _other(on: DateTime(2026, 7, 4), amount: 500),
      ]);
      final month = summary.months.single;
      expect(month.takeHomeMinor + month.deductionsMinor, month.grossMinor);
    });
  });

  group('deduction breakdown', () {
    test('same label across two paycheques is summed, largest first', () {
      final summary = EarningsSummary.from([
        _paycheque(
          on: DateTime(2026, 7, 10),
          gross: 1500,
          deductions: [(label: 'PAYE', amount: 200), (label: 'NSSF', amount: 150)],
        ),
        _paycheque(
          on: DateTime(2026, 7, 25),
          gross: 1500,
          deductions: [(label: 'PAYE', amount: 250), (label: 'NSSF', amount: 150)],
        ),
      ]);
      final deductions = summary.months.single.deductions;
      expect(deductions.map((d) => d.label).toList(), ['PAYE', 'NSSF']);
      expect(deductions.first.amountMinor, 450);
      expect(deductions.last.amountMinor, 300);
    });

    test('all-time breakdown spans months', () {
      final summary = EarningsSummary.from([
        _paycheque(
          on: DateTime(2026, 6, 25),
          gross: 1000,
          deductions: [(label: 'PAYE', amount: 100)],
        ),
        _paycheque(
          on: DateTime(2026, 7, 25),
          gross: 1000,
          deductions: [(label: 'PAYE', amount: 120), (label: 'Union', amount: 500)],
        ),
      ]);
      final totals = summary.deductionsAcrossAllMonths;
      expect(totals.first.label, 'Union');
      expect(totals.first.amountMinor, 500);
      expect(
        totals.firstWhere((d) => d.label == 'PAYE').amountMinor,
        220,
      );
    });
  });

  group('headline rate', () {
    test('is weighted by gross, not averaged across months', () {
      // A tiny month at 50% must not drag the headline up to ~35%; weighting
      // by gross keeps it near the big month's 20%.
      final summary = EarningsSummary.from([
        _paycheque(
          on: DateTime(2026, 6, 25),
          gross: 10000,
          deductions: [(label: 'PAYE', amount: 2000)],
        ),
        _paycheque(
          on: DateTime(2026, 7, 25),
          gross: 100,
          deductions: [(label: 'PAYE', amount: 50)],
        ),
      ]);
      expect(summary.grossTotalMinor, 10100);
      expect(summary.deductionsTotalMinor, 2050);
      expect(summary.effectiveDeductionRate, closeTo(2050 / 10100, 1e-9));
      expect(summary.effectiveDeductionRate, lessThan(0.25));
    });

    test('no gross means no divide-by-zero', () {
      final summary = EarningsSummary.from([
        _other(on: DateTime(2026, 7, 4), amount: 0),
      ]);
      expect(summary.effectiveDeductionRate, 0);
      expect(summary.effectiveDeductionRate.isFinite, isTrue);
      expect(summary.months.single.deductionRate.isFinite, isTrue);
    });
  });

  group('month-on-month change', () {
    test('compares the newest month with the one before it', () {
      final summary = EarningsSummary.from([
        _other(on: DateTime(2026, 6, 10), amount: 1000),
        _other(on: DateTime(2026, 7, 10), amount: 1250),
      ]);
      expect(summary.takeHomeChangeMinor, 250);
    });

    test('reports a drop as a negative', () {
      final summary = EarningsSummary.from([
        _other(on: DateTime(2026, 6, 10), amount: 1000),
        _other(on: DateTime(2026, 7, 10), amount: 800),
      ]);
      expect(summary.takeHomeChangeMinor, -200);
    });

    test('is null with only one month to go on', () {
      final summary = EarningsSummary.from([
        _other(on: DateTime(2026, 7, 10), amount: 1000),
      ]);
      expect(summary.takeHomeChangeMinor, isNull);
    });
  });

  test('limitedTo keeps the most recent months', () {
    final summary = EarningsSummary.from([
      for (var month = 1; month <= 6; month++)
        _other(on: DateTime(2026, month, 10), amount: month * 100),
    ]);
    final limited = summary.limitedTo(3);
    expect(limited.months, hasLength(3));
    expect(limited.months.first.month, DateTime(2026, 6));
    expect(limited.months.last.month, DateTime(2026, 4));
  });
}
