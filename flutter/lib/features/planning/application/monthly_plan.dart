import 'package:fintrack/features/buckets/application/bucket.dart';

/// One income the user expects to receive in a given month.
///
/// Named rather than a single lump sum so a shortfall can say *which* income
/// didn't land — "salary arrived, freelance hasn't" is actionable in a way that
/// "you're 500 short" is not.
class ExpectedIncome {
  const ExpectedIncome({
    required this.id,
    required this.label,
    required this.amountMinor,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final int amountMinor;
  final int sortOrder;

  ExpectedIncome copyWith({
    String? id,
    String? label,
    int? amountMinor,
    int? sortOrder,
  }) {
    return ExpectedIncome(
      id: id ?? this.id,
      label: label ?? this.label,
      amountMinor: amountMinor ?? this.amountMinor,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// What the user intended for one month: expected income and per-bucket spend.
///
/// Stored per month rather than read off the buckets so that editing a plan in
/// July does not retroactively rewrite what June's plan was. See
/// [isSnapshot] for the one case where that guarantee doesn't hold.
class MonthlyPlan {
  const MonthlyPlan({
    required this.month,
    required this.expectedIncomes,
    required this.bucketPlans,
    required this.isSnapshot,
  });

  /// A plan for [month] synthesised from the buckets' own default planned
  /// amounts, used when no snapshot was ever written for that month.
  factory MonthlyPlan.fromBucketDefaults({
    required DateTime month,
    required List<Bucket> buckets,
    List<ExpectedIncome> expectedIncomes = const [],
  }) {
    return MonthlyPlan(
      month: normaliseMonth(month),
      expectedIncomes: expectedIncomes,
      bucketPlans: {
        for (final bucket in buckets)
          if (bucket.plannedMinor != null) bucket.id: bucket.plannedMinor!,
      },
      isSnapshot: false,
    );
  }

  /// Normalised to the first of the month — the plan's identity is the month,
  /// not a day within it.
  final DateTime month;
  final List<ExpectedIncome> expectedIncomes;

  /// bucketId -> planned spend for this month, in minor units.
  final Map<String, int> bucketPlans;

  /// Whether this plan was actually recorded for [month], as opposed to being
  /// synthesised from the buckets' current defaults.
  ///
  /// A synthesised plan moves when the user edits a bucket, so any month
  /// showing `false` must be labelled in the UI as "shown against your current
  /// plan" rather than presented as history.
  final bool isSnapshot;

  int get expectedIncomeTotalMinor =>
      expectedIncomes.fold(0, (sum, income) => sum + income.amountMinor);

  int get plannedSpendTotalMinor =>
      bucketPlans.values.fold(0, (sum, amount) => sum + amount);

  int plannedForBucket(String bucketId) => bucketPlans[bucketId] ?? 0;

  bool get isEmpty => expectedIncomes.isEmpty && plannedSpendTotalMinor == 0;

  MonthlyPlan copyWith({
    List<ExpectedIncome>? expectedIncomes,
    Map<String, int>? bucketPlans,
    bool? isSnapshot,
  }) {
    return MonthlyPlan(
      month: month,
      expectedIncomes: expectedIncomes ?? this.expectedIncomes,
      bucketPlans: bucketPlans ?? this.bucketPlans,
      isSnapshot: isSnapshot ?? this.isSnapshot,
    );
  }
}

/// The first instant of [date]'s month. Plans are keyed by month, so every
/// entry point normalises before comparing or storing.
DateTime normaliseMonth(DateTime date) => DateTime(date.year, date.month);

/// Document id for a month's plan, e.g. `2026-07`. Sorts lexicographically in
/// calendar order, which keeps "most recent plan" a plain `orderBy` query.
String monthKey(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-'
    '${month.month.toString().padLeft(2, '0')}';
