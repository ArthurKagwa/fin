import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintrack/core/errors/app_failure.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/core/utils/combine_latest.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/income/data/income_repository.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plan_repository.g.dart';

abstract class PlanRepository {
  /// Reads the plan for [month]. Never writes — see [ensureCurrentMonthPlan]
  /// for the one place a plan is created implicitly.
  Stream<MonthlyPlan> watchPlan(DateTime month);

  /// The plan for [month] joined with that month's actuals.
  Stream<PlanVsActual> watchPlanVsActual(DateTime month);

  /// Snapshots the current month's plan if it has not been recorded yet, so
  /// that later edits to a bucket's default cannot rewrite this month's plan
  /// after the fact. Safe to call repeatedly.
  Future<void> ensureCurrentMonthPlan();

  Future<void> savePlan(MonthlyPlan plan);
}

class FirestorePlanRepository implements PlanRepository {
  FirestorePlanRepository(
    this._firestore,
    this._uid,
    this._bucketRepository,
    this._expenseRepository,
    this._incomeRepository,
  );

  final FirebaseFirestore _firestore;
  final String _uid;
  final BucketRepository _bucketRepository;
  final ExpenseRepository _expenseRepository;
  final IncomeRepository _incomeRepository;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('monthlyPlans');

  CollectionReference<Map<String, dynamic>> get _buckets =>
      _firestore.collection('users').doc(_uid).collection('buckets');

  @override
  Stream<MonthlyPlan> watchPlan(DateTime month) {
    final resolved = normaliseMonth(month);
    return combineLatest2(
      _collection.doc(monthKey(resolved)).snapshots(),
      _bucketRepository.watchActiveBuckets(),
      (
        DocumentSnapshot<Map<String, dynamic>> doc,
        List<Bucket> buckets,
      ) =>
          _planFrom(doc, buckets, resolved),
    ).handleError(_mapError);
  }

  @override
  Stream<PlanVsActual> watchPlanVsActual(DateTime month) {
    final resolved = normaliseMonth(month);
    // Subscribes to the plan document directly rather than reusing
    // [watchPlan], which would open a second listener on the same buckets
    // collection just to hand the same list back.
    return combineLatest4(
      _collection.doc(monthKey(resolved)).snapshots(),
      _bucketRepository.watchActiveBuckets(),
      _expenseRepository.watchExpenses(month: resolved),
      _incomeRepository.watchIncomeEvents(month: resolved),
      (
        DocumentSnapshot<Map<String, dynamic>> doc,
        List<Bucket> buckets,
        List<Expense> expenses,
        List<IncomeEvent> incomeEvents,
      ) =>
          PlanVsActual.from(
        month: resolved,
        plan: _planFrom(doc, buckets, resolved),
        buckets: buckets,
        expenses: expenses,
        incomeEvents: incomeEvents,
      ),
    ).handleError(_mapError);
  }

  @override
  Future<void> ensureCurrentMonthPlan() async {
    final month = normaliseMonth(DateTime.now());
    final docRef = _collection.doc(monthKey(month));
    try {
      // Fast path: skip the transaction on every app start once the month has
      // been snapshotted.
      if ((await docRef.get()).exists) return;

      final bucketDocs = await _buckets.orderBy('sortOrder').get();
      final bucketPlans = <String, int>{};
      for (final doc in bucketDocs.docs) {
        final planned = doc.data()['plannedMinor'] as num?;
        if (planned != null) bucketPlans[doc.id] = planned.toInt();
      }

      // Carry the previous month's expected income forward — the sources are
      // usually the same month to month, and an empty income plan would make
      // the whole report read as "no plan".
      final previous = await _collection
          .where('month', isLessThan: Timestamp.fromDate(month))
          .orderBy('month', descending: true)
          .limit(1)
          .get();
      final expectedIncomes = previous.docs.isEmpty
          ? const <Map<String, dynamic>>[]
          : (previous.docs.first.data()['expectedIncomes'] as List<dynamic>? ??
                  const [])
              .cast<Map<String, dynamic>>();

      await _firestore.runTransaction((tx) async {
        // Re-check inside the transaction: two devices opened on the 1st would
        // otherwise both write, and the loser would clobber the winner.
        final fresh = await tx.get(docRef);
        if (fresh.exists) return;
        tx.set(docRef, {
          'month': Timestamp.fromDate(month),
          'expectedIncomes': expectedIncomes,
          'bucketPlans': bucketPlans,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
      });
    } on FirebaseException catch (error) {
      throw _mapException(error);
    }
  }

  @override
  Future<void> savePlan(MonthlyPlan plan) async {
    final month = normaliseMonth(plan.month);
    try {
      await _collection.doc(monthKey(month)).set({
        'month': Timestamp.fromDate(month),
        'expectedIncomes': [
          for (final income in plan.expectedIncomes)
            {
              'id': income.id,
              'label': income.label,
              'amountMinor': income.amountMinor,
              'sortOrder': income.sortOrder,
            },
        ],
        'bucketPlans': plan.bucketPlans,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      throw _mapException(error);
    }
  }

  MonthlyPlan _planFrom(
    DocumentSnapshot<Map<String, dynamic>> doc,
    List<Bucket> buckets,
    DateTime month,
  ) {
    final data = doc.data();
    if (!doc.exists || data == null) {
      return MonthlyPlan.fromBucketDefaults(month: month, buckets: buckets);
    }

    final expectedIncomes =
        (data['expectedIncomes'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(
              // Money is read through `num` rather than cast straight to int:
              // a value that ever round-tripped through JSON comes back as a
              // double, and a hard cast would throw on the whole month.
              (raw) => ExpectedIncome(
                id: raw['id'] as String,
                label: raw['label'] as String,
                amountMinor: (raw['amountMinor'] as num).toInt(),
                sortOrder: (raw['sortOrder'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final bucketPlans = <String, int>{
      for (final entry
          in (data['bucketPlans'] as Map<String, dynamic>? ?? const {}).entries)
        entry.key: (entry.value as num).toInt(),
    };

    // A bucket created after this month was snapshotted has no entry. For the
    // current month, fold in its own default so a bucket added on the 10th
    // isn't reported as unplanned. Past months stay strict: absence there is
    // history, and filling it from today's defaults would be a fabrication.
    final currentMonth = normaliseMonth(DateTime.now());
    if (month.year == currentMonth.year && month.month == currentMonth.month) {
      for (final bucket in buckets) {
        if (!bucketPlans.containsKey(bucket.id) && bucket.plannedMinor != null) {
          bucketPlans[bucket.id] = bucket.plannedMinor!;
        }
      }
    }

    return MonthlyPlan(
      month: month,
      expectedIncomes: expectedIncomes,
      bucketPlans: bucketPlans,
      isSnapshot: true,
    );
  }

  Never _mapError(Object error) {
    if (error is FirebaseException) throw _mapException(error);
    throw error;
  }

  AppFailure _mapException(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => const PermissionFailure(
          "You don't have access to this plan.",
        ),
      'unavailable' || 'deadline-exceeded' => const NetworkFailure(
          "Couldn't reach your plan — check your connection.",
        ),
      'not-found' => const NotFoundFailure('That plan no longer exists.'),
      _ => NetworkFailure(error.message ?? 'Something went wrong.'),
    };
  }
}

@Riverpod(keepAlive: true)
PlanRepository planRepository(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('planRepository read while signed out');
  return FirestorePlanRepository(
    ref.watch(firebaseFirestoreProvider),
    uid,
    ref.watch(bucketRepositoryProvider),
    ref.watch(expenseRepositoryProvider),
    ref.watch(incomeRepositoryProvider),
  );
}

@riverpod
Stream<MonthlyPlan> monthlyPlan(Ref ref, DateTime month) =>
    ref.watch(planRepositoryProvider).watchPlan(normaliseMonth(month));

@riverpod
Stream<PlanVsActual> planVsActual(Ref ref, DateTime month) =>
    ref.watch(planRepositoryProvider).watchPlanVsActual(normaliseMonth(month));
