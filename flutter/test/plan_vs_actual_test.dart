import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 30-day month, so that "half the month" is an exact 15 days.
final _june = DateTime(2026, 6);

VarianceLine _spend({
  required int planned,
  required int actual,
  double progress = 0.5,
}) =>
    VarianceLine(
      label: 'Food',
      plannedMinor: planned,
      actualMinor: actual,
      higherIsBetter: false,
      monthProgress: progress,
    );

VarianceLine _income({
  required int planned,
  required int actual,
  double progress = 0.5,
}) =>
    VarianceLine(
      label: 'Money in',
      plannedMinor: planned,
      actualMinor: actual,
      higherIsBetter: true,
      monthProgress: progress,
    );

Bucket _bucket(String id, {String? name, int? planned}) =>
    Bucket(id: id, name: name ?? id, sortOrder: 0, plannedMinor: planned);

Expense _expense(String bucketId, int amount) => Expense(
      id: '$bucketId-$amount',
      bucketId: bucketId,
      amountMinor: amount,
      occurredOn: DateTime(2026, 6, 10),
    );

IncomeEvent _incomeEvent(String source, int amount) => IncomeEvent(
      id: '$source-$amount',
      kind: IncomeKind.paycheque,
      amountMinor: amount,
      occurredOn: DateTime(2026, 6, 10),
      source: source,
    );

void main() {
  group('VarianceLine — spend (under plan is good)', () {
    test('under both plan and pace is on track', () {
      expect(_spend(planned: 1000, actual: 400).state, VarianceState.onTrack);
    });

    test('past pace but still under plan is off pace, not off plan', () {
      // The whole point of the ladder: 700 of 1000 at the halfway mark is
      // worth noticing, but it is not an overspend and must not read as one.
      expect(_spend(planned: 1000, actual: 700).state, VarianceState.offPace);
    });

    test('past the full-month plan is off plan', () {
      expect(_spend(planned: 1000, actual: 1001).state, VarianceState.offPlan);
    });

    test('exactly on pace is on track, not off pace', () {
      expect(_spend(planned: 1000, actual: 500).state, VarianceState.onTrack);
    });

    test('exactly on plan is not yet off plan', () {
      expect(
        _spend(planned: 1000, actual: 1000, progress: 1).state,
        VarianceState.onTrack,
      );
    });

    test('spending fast early never reads as an overspend', () {
      // The bug this feature exists to fix: a flat 85%-of-plan threshold fired
      // identically on day 2 and day 28. Running hot on day 2 is worth saying
      // out loud, but it is not the same event as blowing the plan.
      final earlyBurst = _spend(planned: 1000, actual: 900, progress: 2 / 30);
      expect(earlyBurst.state, VarianceState.offPace);
      expect(earlyBurst.state, isNot(VarianceState.offPlan));
    });

    test('the same 900 of 1000 is on track once the month has nearly run', () {
      // Same numbers, opposite verdict — which is exactly the point. A fixed
      // percentage threshold cannot tell these two situations apart.
      expect(
        _spend(planned: 1000, actual: 900, progress: 28 / 30).state,
        VarianceState.onTrack,
      );
    });
  });

  group('VarianceLine — income (under plan is bad)', () {
    test('short of plan but on pace is on track', () {
      expect(_income(planned: 1000, actual: 500).state, VarianceState.onTrack);
    });

    test('short of pace is off pace', () {
      expect(_income(planned: 1000, actual: 200).state, VarianceState.offPace);
    });

    test('above plan is on track — earning more is never a problem', () {
      expect(_income(planned: 1000, actual: 1500).state, VarianceState.onTrack);
    });

    test('income never reaches offPlan', () {
      for (final actual in [0, 500, 1000, 5000]) {
        expect(
          _income(planned: 1000, actual: actual).state,
          isNot(VarianceState.offPlan),
        );
      }
    });

    test('the same numbers read oppositely for income and spend', () {
      // Guards the sign convention: 900 of 1000 spent is a warning, 900 of
      // 1000 earned is fine.
      expect(_spend(planned: 1000, actual: 900).state, VarianceState.offPace);
      expect(_income(planned: 1000, actual: 900).state, VarianceState.onTrack);
    });
  });

  group('pace maths', () {
    test('paced target is zero on day zero and the full plan at month end', () {
      expect(_spend(planned: 3000, actual: 0, progress: 0).pacedTargetMinor, 0);
      expect(
        _spend(planned: 3000, actual: 0, progress: 1).pacedTargetMinor,
        3000,
      );
    });

    test('paced target tracks a 31-day month', () {
      final line = _spend(planned: 3100, actual: 0, progress: 10 / 31);
      expect(line.pacedTargetMinor, 1000);
    });

    test('paced target tracks a 29-day leap February', () {
      final daysInFeb = DateTime(2024, 3, 0).day;
      expect(daysInFeb, 29);
      final line = _spend(planned: 2900, actual: 0, progress: 10 / daysInFeb);
      expect(line.pacedTargetMinor, 1000);
    });

    test('progress beyond the month is clamped', () {
      expect(
        _spend(planned: 1000, actual: 0, progress: 1.5).pacedTargetMinor,
        1000,
      );
    });
  });

  group('no plan', () {
    test('produces no NaN or Infinity and no divide-by-zero', () {
      final line = _spend(planned: 0, actual: 500);
      expect(line.hasPlan, isFalse);
      expect(line.actualRatio, 0);
      expect(line.actualRatio.isFinite, isTrue);
      expect(line.pacedTargetMinor, 0);
      expect(line.state, VarianceState.onTrack);
    });

    test('an empty report divides by nothing', () {
      final report = PlanVsActual.from(
        month: _june,
        plan: MonthlyPlan(
          month: _june,
          expectedIncomes: const [],
          bucketPlans: const {},
          isSnapshot: true,
        ),
        buckets: const [],
        expenses: const [],
        incomeEvents: const [],
        now: DateTime(2026, 6, 15),
      );
      expect(report.monthProgress.isFinite, isTrue);
      expect(report.income.actualRatio.isFinite, isTrue);
      expect(report.spend.actualRatio.isFinite, isTrue);
      expect(report.projectedSpendMinor, 0);
      expect(report.leftToSpendMinor, 0);
      expect(report.hasPlan, isFalse);
      expect(report.hasActuals, isFalse);
    });
  });

  group('MonthlyPlan', () {
    test('synthesised from bucket defaults is flagged as not a snapshot', () {
      final plan = MonthlyPlan.fromBucketDefaults(
        month: _june,
        buckets: [_bucket('a', planned: 500), _bucket('b', planned: 300)],
      );
      expect(plan.isSnapshot, isFalse);
      expect(plan.plannedSpendTotalMinor, 800);
      expect(plan.plannedForBucket('a'), 500);
    });

    test('buckets with no planned amount are left out, not zeroed in', () {
      final plan = MonthlyPlan.fromBucketDefaults(
        month: _june,
        buckets: [_bucket('a', planned: 500), _bucket('b')],
      );
      expect(plan.bucketPlans.containsKey('b'), isFalse);
      expect(plan.plannedForBucket('b'), 0);
    });

    test('month key sorts in calendar order', () {
      expect(monthKey(DateTime(2026, 7)), '2026-07');
      expect(monthKey(DateTime(2026, 12)), '2026-12');
      final keys = [
        monthKey(DateTime(2026, 12)),
        monthKey(DateTime(2027, 1)),
        monthKey(DateTime(2026, 2)),
      ]..sort();
      expect(keys, ['2026-02', '2026-12', '2027-01']);
    });

    test('normalising drops the day', () {
      expect(normaliseMonth(DateTime(2026, 6, 17, 13, 45)), DateTime(2026, 6));
    });
  });

  group('PlanVsActual assembly', () {
    PlanVsActual build({
      List<Bucket> buckets = const [],
      List<Expense> expenses = const [],
      List<IncomeEvent> incomeEvents = const [],
      List<ExpectedIncome> expectedIncomes = const [],
      Map<String, int> bucketPlans = const {},
      DateTime? now,
    }) {
      return PlanVsActual.from(
        month: _june,
        plan: MonthlyPlan(
          month: _june,
          expectedIncomes: expectedIncomes,
          bucketPlans: bucketPlans,
          isSnapshot: true,
        ),
        buckets: buckets,
        expenses: expenses,
        incomeEvents: incomeEvents,
        now: now ?? DateTime(2026, 6, 15),
      );
    }

    test('buckets are ranked by absolute variance, biggest miss first', () {
      final report = build(
        buckets: [_bucket('a'), _bucket('b'), _bucket('c')],
        bucketPlans: const {'a': 1000, 'b': 1000, 'c': 1000},
        expenses: [
          _expense('a', 1050), // variance   +50
          _expense('b', 100), //  variance  -900
          _expense('c', 1300), // variance  +300
        ],
      );
      expect(
        report.buckets.map((b) => b.bucket.id).toList(),
        ['b', 'c', 'a'],
      );
    });

    test('ranking is by magnitude, so a large underspend outranks a small over',
        () {
      final report = build(
        buckets: [_bucket('under'), _bucket('over')],
        bucketPlans: const {'under': 5000, 'over': 1000},
        expenses: [_expense('over', 1100)],
      );
      expect(report.buckets.first.bucket.id, 'under');
    });

    test('a bucket with no plan and no spend is marked untouched', () {
      final report = build(buckets: [_bucket('idle')]);
      expect(report.buckets.single.isUntouched, isTrue);
    });

    test('left to spend is plan minus actual, and goes negative on overspend',
        () {
      final report = build(
        buckets: [_bucket('a')],
        bucketPlans: const {'a': 1000},
        expenses: [_expense('a', 1200)],
      );
      expect(report.leftToSpendMinor, -200);
    });

    test('net cash is income received less money spent', () {
      final report = build(
        buckets: [_bucket('a')],
        bucketPlans: const {'a': 1000},
        expenses: [_expense('a', 400)],
        incomeEvents: [_incomeEvent('Salary', 1500)],
      );
      expect(report.netCashMinor, 1100);
    });

    test('projected spend extrapolates the month straight-line', () {
      final report = build(
        buckets: [_bucket('a')],
        bucketPlans: const {'a': 1000},
        expenses: [_expense('a', 500)],
        now: DateTime(2026, 6, 15), // 15 of 30 days
      );
      expect(report.monthProgress, 0.5);
      expect(report.projectedSpendMinor, 1000);
    });

    test('planned overspend flags a plan that outspends expected income', () {
      final report = build(
        buckets: [_bucket('a')],
        bucketPlans: const {'a': 3000},
        expectedIncomes: const [
          ExpectedIncome(id: '1', label: 'Salary', amountMinor: 2500, sortOrder: 0),
        ],
      );
      expect(report.plannedOverspendMinor, 500);
    });

    test('a fully funded plan flags nothing', () {
      final report = build(
        buckets: [_bucket('a')],
        bucketPlans: const {'a': 2000},
        expectedIncomes: const [
          ExpectedIncome(id: '1', label: 'Salary', amountMinor: 2500, sortOrder: 0),
        ],
      );
      expect(report.plannedOverspendMinor, 0);
    });

    test('days elapsed is the whole month once the month has passed', () {
      final report = build(now: DateTime(2026, 9, 3));
      expect(report.daysElapsed, 30);
      expect(report.monthProgress, 1);
      expect(report.daysRemaining, 0);
    });

    test('a future month has not started', () {
      final report = build(now: DateTime(2026, 3, 20));
      expect(report.daysElapsed, 0);
      expect(report.monthProgress, 0);
      expect(report.projectedSpendMinor, 0);
    });
  });

  group('income source matching', () {
    PlanVsActual build(
      List<ExpectedIncome> expected,
      List<IncomeEvent> events,
    ) {
      return PlanVsActual.from(
        month: _june,
        plan: MonthlyPlan(
          month: _june,
          expectedIncomes: expected,
          bucketPlans: const {},
          isSnapshot: true,
        ),
        buckets: const [],
        expenses: const [],
        incomeEvents: events,
        now: DateTime(2026, 6, 15),
      );
    }

    test('matches sources case- and whitespace-insensitively', () {
      final report = build(
        const [
          ExpectedIncome(id: '1', label: 'Salary', amountMinor: 3000, sortOrder: 0),
        ],
        [_incomeEvent('  salary ', 3000)],
      );
      expect(report.incomeSources.single.label, 'Salary');
      expect(report.incomeSources.single.actualMinor, 3000);
      expect(report.incomeSources.single.hasArrived, isTrue);
    });

    test('a source that has not landed reports zero, not absence', () {
      final report = build(
        const [
          ExpectedIncome(id: '1', label: 'Salary', amountMinor: 3000, sortOrder: 0),
          ExpectedIncome(id: '2', label: 'Freelance', amountMinor: 500, sortOrder: 1),
        ],
        [_incomeEvent('Salary', 3000)],
      );
      final freelance = report.incomeSources[1];
      expect(freelance.label, 'Freelance');
      expect(freelance.hasArrived, isFalse);
      expect(freelance.varianceMinor, -500);
    });

    test('unmatched income lands in a catch-all so totals reconcile', () {
      final report = build(
        const [
          ExpectedIncome(id: '1', label: 'Salary', amountMinor: 3000, sortOrder: 0),
        ],
        [_incomeEvent('Salary', 3000), _incomeEvent('Birthday gift', 200)],
      );
      final unplanned = report.incomeSources.last;
      expect(unplanned.isUnplanned, isTrue);
      expect(unplanned.actualMinor, 200);
      expect(
        report.incomeSources.fold<int>(0, (sum, s) => sum + s.actualMinor),
        report.income.actualMinor,
      );
    });

    test('several events against one source are summed', () {
      final report = build(
        const [
          ExpectedIncome(id: '1', label: 'Salary', amountMinor: 3000, sortOrder: 0),
        ],
        [_incomeEvent('Salary', 1500), _incomeEvent('Salary', 1400)],
      );
      expect(report.incomeSources.single.actualMinor, 2900);
    });

    test('no catch-all row appears when everything matched', () {
      final report = build(
        const [
          ExpectedIncome(id: '1', label: 'Salary', amountMinor: 3000, sortOrder: 0),
        ],
        [_incomeEvent('Salary', 3000)],
      );
      expect(report.incomeSources.any((s) => s.isUnplanned), isFalse);
    });

    test('sources are listed in their configured order', () {
      final report = build(
        const [
          ExpectedIncome(id: '2', label: 'Freelance', amountMinor: 500, sortOrder: 1),
          ExpectedIncome(id: '1', label: 'Salary', amountMinor: 3000, sortOrder: 0),
        ],
        const [],
      );
      expect(
        report.incomeSources.map((s) => s.label).toList(),
        ['Salary', 'Freelance'],
      );
    });
  });
}
