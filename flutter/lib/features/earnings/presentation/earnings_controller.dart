import 'package:fintrack/features/earnings/application/earnings_summary.dart';
import 'package:fintrack/features/income/data/income_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'earnings_controller.g.dart';

/// A different reading of the income records the app already keeps, not a
/// second source of truth. Exposed as a stream rather than derived from
/// [incomeEventsProvider]'s `AsyncValue` so the screen keeps real loading and
/// error branches instead of silently rendering an empty report.
@riverpod
Stream<EarningsSummary> earningsSummary(Ref ref) => ref
    .watch(incomeRepositoryProvider)
    .watchIncomeEvents()
    .map(EarningsSummary.from);
