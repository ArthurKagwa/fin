import 'package:fintrack/features/buckets/application/bucket.dart';

class BucketSummary {
  const BucketSummary({
    required this.bucket,
    required this.allocatedThisMonthMinor,
    required this.spentThisMonthMinor,
    required this.balanceMinor,
    required this.carriedOverMinor,
  });

  final Bucket bucket;
  final int allocatedThisMonthMinor;
  final int spentThisMonthMinor;
  final int balanceMinor;
  final int carriedOverMinor;

  int get remainingMinor => balanceMinor;
  int get plannedMinor => bucket.plannedMinor ?? 0;
}

class DashboardSummary {
  const DashboardSummary({
    required this.month,
    required this.buckets,
    required this.unallocatedMinor,
    required this.daysElapsed,
    required this.daysInMonth,
  });

  final DateTime month;
  final List<BucketSummary> buckets;
  final int unallocatedMinor;
  final int daysElapsed;
  final int daysInMonth;

  double get monthProgress => daysInMonth > 0 ? daysElapsed / daysInMonth : 0;
}
