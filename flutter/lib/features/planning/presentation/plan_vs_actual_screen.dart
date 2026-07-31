import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:fintrack/features/planning/data/plan_repository.dart';
import 'package:fintrack/features/planning/presentation/plan_controller.dart';
import 'package:fintrack/features/planning/presentation/widgets/plan_summary.dart';
import 'package:fintrack/features/planning/presentation/widgets/variance_row.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The drill-down: "where is it going wrong?", one tap from the dashboard's
/// "am I OK?".
class PlanVsActualScreen extends ConsumerWidget {
  const PlanVsActualScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedPlanMonthProvider);
    final reportAsync = ref.watch(planVsActualProvider(month));
    final currency = ref.watch(currencyCodeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan vs actual')),
      body: Column(
        children: [
          const _MonthPicker(),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load this month: $error'),
                ),
              ),
              data: (report) => _ReportBody(report: report, currency: currency),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/plan/edit'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit plan'),
      ),
    );
  }
}

class _MonthPicker extends ConsumerWidget {
  const _MonthPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedPlanMonthProvider);
    final notifier = ref.read(selectedPlanMonthProvider.notifier);
    final canGoForward = notifier.canGoForward;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: notifier.previous,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
          ),
          Expanded(
            child: Text(
              formatMonth(month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            // Disabled past today: a future month is all plan and no actual,
            // so there is nothing to compare.
            onPressed: canGoForward ? notifier.next : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.currency});

  final PlanVsActual report;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!report.hasPlan && !report.hasActuals) {
      return _EmptyMonth(isCurrentMonth: report.isCurrentMonth);
    }

    final tracked = report.buckets.where((b) => !b.isUntouched).toList();
    final untouchedCount = report.buckets.length - tracked.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PlanSummary(report: report, currency: currency),
          ),
        ),
        const SizedBox(height: 28),
        Text('Money in', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (report.incomeSources.isEmpty)
          const _SectionNote(text: 'No expected income set for this month.')
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (var i = 0; i < report.incomeSources.length; i++) ...[
                    if (i > 0) const _RowDivider(),
                    _IncomeSourceRow(
                      source: report.incomeSources[i],
                      currency: currency,
                      monthProgress: report.monthProgress,
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 28),
        Text('Money out', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          // Say the ordering out loud — otherwise a list that isn't alphabetical
          // just looks arbitrary.
          'Biggest difference from plan first',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (tracked.isEmpty)
          const _SectionNote(text: 'Nothing planned or spent this month.')
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (var i = 0; i < tracked.length; i++) ...[
                    if (i > 0) const _RowDivider(),
                    VarianceRow(line: tracked[i].line, currency: currency),
                  ],
                ],
              ),
            ),
          ),
        if (untouchedCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            '$untouchedCount ${untouchedCount == 1 ? 'bucket has' : 'buckets have'} '
            'no plan and no spend this month.',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _IncomeSourceRow extends StatelessWidget {
  const _IncomeSourceRow({
    required this.source,
    required this.currency,
    required this.monthProgress,
  });

  final ExpectedIncomeLine source;
  final String currency;
  final double monthProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Income that matched no expected source is a pleasant surprise, not a
    // variance — a bar against a plan of zero would be meaningless.
    if (source.isUnplanned) {
      return Row(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 16, color: colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(source.label, style: theme.textTheme.titleMedium),
          ),
          Text(
            '+${formatMoney(source.actualMinor, symbol: currency)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.secondary,
            ),
          ),
        ],
      );
    }

    if (!source.hasArrived) {
      return Row(
        children: [
          Icon(Icons.schedule, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.label, style: theme.textTheme.titleMedium),
                Text(
                  'Not yet received',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(source.expectedMinor, symbol: currency),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return VarianceRow(
      line: VarianceLine(
        label: source.label,
        plannedMinor: source.expectedMinor,
        actualMinor: source.actualMinor,
        higherIsBetter: true,
        monthProgress: monthProgress,
      ),
      currency: currency,
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
      ),
    );
  }
}

class _SectionNote extends StatelessWidget {
  const _SectionNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.isCurrentMonth});

  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nothing here yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              isCurrentMonth
                  ? 'Set what you expect to earn and what each bucket should '
                      'spend, and this fills in as the month goes.'
                  : 'No plan and no activity were recorded for this month.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
