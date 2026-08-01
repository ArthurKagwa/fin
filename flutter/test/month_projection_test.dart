import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/planning/application/month_projection.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:fintrack/features/recurring/application/recurring_payment.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 30-day month, so "half the month" is an exact 15 days.
final _june = DateTime(2026, 6);
final _midJune = DateTime(2026, 6, 15);

final _housing = Bucket(id: 'housing', name: 'Housing', sortOrder: 0);
final _food = Bucket(id: 'food', name: 'Food', sortOrder: 1);

MonthlyPlan _plan({int? plannedHousing, int? plannedFood, int? expectedIncome}) =>
    MonthlyPlan(
      month: _june,
      expectedIncomes: expectedIncome == null
          ? const []
          : [
              ExpectedIncome(
                id: 'salary',
                label: 'Salary',
                amountMinor: expectedIncome,
                sortOrder: 0,
              ),
            ],
      bucketPlans: {
        if (plannedHousing != null) 'housing': plannedHousing,
        if (plannedFood != null) 'food': plannedFood,
      },
      isSnapshot: true,
    );

Expense _expense(
  String id,
  String bucketId,
  int amountMinor,
  DateTime occurredOn, {
  String? occurrenceId,
}) =>
    Expense(
      id: id,
      bucketId: bucketId,
      amountMinor: amountMinor,
      occurredOn: occurredOn,
      occurrenceId: occurrenceId,
    );

RecurringPayment _rent({
  required DateTime startOn,
  int amountMinor = 100000,
  DateTime? endOn,
}) =>
    RecurringPayment(
      id: 'rent',
      name: 'Rent',
      bucketId: 'housing',
      frequency: RecurringFrequency.monthly,
      startOn: startOn,
      endOn: endOn,
      ratePeriods: [
        RatePeriod(id: 'r1', amountMinor: amountMinor, effectiveFrom: startOn),
      ],
    );

MonthProjection _projectionFor({
  required List<Expense> expenses,
  List<RecurringPayment> payments = const [],
  List<IncomeEvent> incomeEvents = const [],
  MonthlyPlan? plan,
  DateTime? now,
  DateTime? month,
}) {
  final resolvedMonth = month ?? _june;
  final resolvedNow = now ?? _midJune;
  final report = PlanVsActual.from(
    month: resolvedMonth,
    plan: plan ?? _plan(),
    buckets: [_housing, _food],
    expenses: expenses,
    incomeEvents: incomeEvents,
    now: resolvedNow,
  );
  return MonthProjection.from(
    report: report,
    expenses: expenses,
    payments: payments,
    now: resolvedNow,
  );
}

void main() {
  group('MonthProjection — a fixed charge is never extrapolated', () {
    test('rent already paid this month is excluded from the run rate', () {
      final rentDueOn = DateTime(2026, 6, 1);
      final projection = _projectionFor(
        expenses: [
          _expense(
            'e1',
            'housing',
            100000,
            rentDueOn,
            occurrenceId: occurrenceIdFor('rent', rentDueOn),
          ),
          _expense('e2', 'food', 30000, DateTime(2026, 6, 10)),
        ],
        payments: [_rent(startOn: rentDueOn)],
      );

      expect(projection.spentMinor, 130000);
      expect(projection.recurringSpentMinor, 100000);
      expect(projection.variableSpentMinor, 30000);
      // 30000 of everyday spend over 15 days, 15 days left.
      expect(projection.variableForecastMinor, 30000);
      // Next rent is due in July, so nothing more is committed this month.
      expect(projection.committedMinor, 0);
      expect(projection.projectedSpendMinor, 160000);
    });

    test('the straight line it replaces would have doubled the rent', () {
      final rentDueOn = DateTime(2026, 6, 1);
      final report = PlanVsActual.from(
        month: _june,
        plan: _plan(),
        buckets: [_housing, _food],
        expenses: [
          _expense(
            'e1',
            'housing',
            100000,
            rentDueOn,
            occurrenceId: occurrenceIdFor('rent', rentDueOn),
          ),
          _expense('e2', 'food', 30000, DateTime(2026, 6, 10)),
        ],
        incomeEvents: const [],
        now: _midJune,
      );

      expect(report.projectedSpendMinor, 260000);
    });
  });

  group('MonthProjection — charges still to come', () {
    test('a charge due later this month is committed once', () {
      final projection = _projectionFor(
        expenses: [_expense('e1', 'food', 30000, DateTime(2026, 6, 10))],
        payments: [_rent(startOn: DateTime(2026, 1, 25))],
      );

      expect(projection.committedMinor, 100000);
      expect(projection.projectedSpendMinor, 30000 + 100000 + 30000);
    });

    test('an overdue but unconfirmed charge still counts as committed', () {
      // Due on the 15th — today — and nothing has been recorded against it.
      final projection = _projectionFor(
        expenses: const [],
        payments: [_rent(startOn: DateTime(2026, 1, 15))],
      );

      expect(projection.committedMinor, 100000);
    });

    test('a charge already confirmed is not counted twice', () {
      final dueOn = DateTime(2026, 6, 25);
      final projection = _projectionFor(
        expenses: [
          _expense(
            'e1',
            'housing',
            100000,
            dueOn,
            occurrenceId: occurrenceIdFor('rent', dueOn),
          ),
        ],
        payments: [_rent(startOn: DateTime(2026, 1, 25))],
      );

      expect(projection.committedMinor, 0);
      expect(projection.spentMinor, 100000);
      expect(projection.projectedSpendMinor, 100000);
    });

    test('a payment that ends before the due date commits nothing', () {
      final projection = _projectionFor(
        expenses: const [],
        payments: [
          _rent(startOn: DateTime(2026, 1, 25), endOn: DateTime(2026, 5, 31)),
        ],
      );

      expect(projection.committedMinor, 0);
    });

    test('the rate in effect on the due date is the one projected', () {
      final payment = RecurringPayment(
        id: 'rent',
        name: 'Rent',
        bucketId: 'housing',
        frequency: RecurringFrequency.monthly,
        startOn: DateTime(2026, 1, 25),
        ratePeriods: [
          RatePeriod(id: 'r1', amountMinor: 100000, effectiveFrom: DateTime(2026, 1, 25)),
          RatePeriod(id: 'r2', amountMinor: 120000, effectiveFrom: DateTime(2026, 6, 1)),
        ],
      );

      final projection = _projectionFor(expenses: const [], payments: [payment]);

      expect(projection.committedMinor, 120000);
    });
  });

  group('MonthProjection — where the month lands', () {
    test('leftover is expected income less the projected spend', () {
      final projection = _projectionFor(
        expenses: [_expense('e1', 'food', 30000, DateTime(2026, 6, 10))],
        plan: _plan(expectedIncome: 500000, plannedFood: 80000),
        incomeEvents: const [],
      );

      expect(projection.projectedIncomeMinor, 500000);
      expect(projection.projectedSpendMinor, 60000);
      expect(projection.projectedLeftoverMinor, 440000);
    });

    test('income already received beats the expectation once it exceeds it', () {
      final projection = _projectionFor(
        expenses: const [],
        plan: _plan(expectedIncome: 500000),
        incomeEvents: [
          IncomeEvent(
            id: 'i1',
            kind: IncomeKind.paycheque,
            amountMinor: 620000,
            occurredOn: DateTime(2026, 6, 5),
            source: 'Salary',
          ),
        ],
      );

      expect(projection.projectedIncomeMinor, 620000);
    });

    test('a projection over plan reports the gap', () {
      final projection = _projectionFor(
        expenses: [_expense('e1', 'food', 60000, DateTime(2026, 6, 10))],
        plan: _plan(plannedFood: 80000),
      );

      // 60000 spent, 60000 more at the same pace, against an 80000 plan.
      expect(projection.projectedSpendMinor, 120000);
      expect(projection.projectedVsPlanMinor, 40000);
    });

    test('a finished month projects nothing beyond its actuals', () {
      final projection = _projectionFor(
        expenses: [_expense('e1', 'food', 30000, DateTime(2026, 6, 10))],
        payments: [_rent(startOn: DateTime(2026, 1, 25))],
        now: DateTime(2026, 7, 15),
      );

      expect(projection.daysRemaining, 0);
      expect(projection.committedMinor, 0);
      expect(projection.variableForecastMinor, 0);
      expect(projection.projectedSpendMinor, 30000);
    });

    test('the run rate is flagged as early before a quarter of the month', () {
      final early = _projectionFor(
        expenses: [_expense('e1', 'food', 30000, DateTime(2026, 6, 2))],
        now: DateTime(2026, 6, 3),
      );
      expect(early.runRateIsMeaningful, isFalse);
      expect(_projectionFor(expenses: const []).runRateIsMeaningful, isTrue);
    });

    test('no plan, no spend and no commitments is empty', () {
      expect(_projectionFor(expenses: const []).isEmpty, isTrue);
    });

    test('a commitment alone is enough to have something to project', () {
      final projection = _projectionFor(
        expenses: const [],
        payments: [_rent(startOn: DateTime(2026, 1, 25))],
      );

      expect(projection.isEmpty, isFalse);
    });
  });
}
