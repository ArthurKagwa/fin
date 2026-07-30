import 'package:fintrack/core/utils/combine_latest.dart';
import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/dashboard/application/dashboard_summary.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_repository.g.dart';

abstract class DashboardRepository {
  Stream<DashboardSummary> watchDashboardSummary({DateTime? month});
}

class FirestoreDashboardRepository implements DashboardRepository {
  FirestoreDashboardRepository(this._bucketRepository, this._expenseRepository);

  final BucketRepository _bucketRepository;
  final ExpenseRepository _expenseRepository;

  @override
  Stream<DashboardSummary> watchDashboardSummary({DateTime? month}) {
    final resolvedMonth = month ?? DateTime.now();
    return combineLatest2(
      _bucketRepository.watchActiveBuckets(),
      _expenseRepository.watchExpenses(month: resolvedMonth),
      (List<Bucket> buckets, List<Expense> expenses) =>
          _buildSummary(buckets, expenses, resolvedMonth),
    );
  }

  DashboardSummary _buildSummary(
    List<Bucket> buckets,
    List<Expense> expenses,
    DateTime month,
  ) {
    final now = DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrentMonth = now.year == month.year && now.month == month.month;
    final daysElapsed = isCurrentMonth ? now.day : daysInMonth;

    final bucketSummaries = buckets.map((bucket) {
      final spentMinor = expenses
          .where((e) => e.bucketId == bucket.id)
          .fold<int>(0, (sum, e) => sum + e.amountMinor);
      final allocatedMinor = bucket.plannedMinor ?? 0;
      return BucketSummary(
        bucket: bucket,
        allocatedThisMonthMinor: allocatedMinor,
        spentThisMonthMinor: spentMinor,
        balanceMinor: allocatedMinor - spentMinor,
        carriedOverMinor: 0,
      );
    }).toList();

    return DashboardSummary(
      month: DateTime(month.year, month.month),
      buckets: bucketSummaries,
      // Allocation-vs-income tracking isn't built yet (US-06); this is always
      // 0 until Money In allocation is wired up.
      unallocatedMinor: 0,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
    );
  }
}

@Riverpod(keepAlive: true)
DashboardRepository dashboardRepository(Ref ref) => FirestoreDashboardRepository(
      ref.watch(bucketRepositoryProvider),
      ref.watch(expenseRepositoryProvider),
    );

@Riverpod(keepAlive: true)
Stream<DashboardSummary> dashboardSummary(Ref ref) =>
    ref.watch(dashboardRepositoryProvider).watchDashboardSummary();
