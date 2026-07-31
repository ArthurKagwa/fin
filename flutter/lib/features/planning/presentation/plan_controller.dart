import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/data/plan_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plan_controller.g.dart';

/// Which month the plan-vs-actual report is showing. Kept alive so paging back
/// to June, opening a bucket and coming back doesn't silently jump to today.
@Riverpod(keepAlive: true)
class SelectedPlanMonth extends _$SelectedPlanMonth {
  @override
  DateTime build() => normaliseMonth(DateTime.now());

  void select(DateTime month) => state = normaliseMonth(month);

  void previous() => state = DateTime(state.year, state.month - 1);

  /// No-op past the current month: there are no actuals to compare a future
  /// plan against, so the report would be all plan and no signal.
  void next() {
    if (!canGoForward) return;
    state = DateTime(state.year, state.month + 1);
  }

  bool get canGoForward {
    final current = normaliseMonth(DateTime.now());
    return state.isBefore(current);
  }
}

@riverpod
class PlanController extends _$PlanController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Fire-and-forget snapshot of the current month, called once when the
  /// dashboard mounts. Failures are swallowed into [state] rather than thrown:
  /// the report falls back to the buckets' own defaults, so a failed snapshot
  /// degrades history, not the screen.
  Future<void> ensureCurrentMonth() async {
    state = await AsyncValue.guard(
      () => ref.read(planRepositoryProvider).ensureCurrentMonthPlan(),
    );
  }

  Future<void> save({
    required DateTime month,
    required List<ExpectedIncome> expectedIncomes,
    required Map<String, int> bucketPlans,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(planRepositoryProvider).savePlan(
            MonthlyPlan(
              month: normaliseMonth(month),
              expectedIncomes: expectedIncomes,
              bucketPlans: bucketPlans,
              isSnapshot: true,
            ),
          ),
    );
  }
}
