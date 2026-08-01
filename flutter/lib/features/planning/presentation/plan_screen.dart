import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:fintrack/features/planning/application/month_projection.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:fintrack/features/planning/data/plan_repository.dart';
import 'package:fintrack/features/planning/presentation/plan_controller.dart';
import 'package:fintrack/features/planning/presentation/plan_editor_form.dart';
import 'package:fintrack/features/planning/presentation/widgets/variance_row.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/recurring/data/recurring_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Budgeting: what you expect to earn this month, and what each bucket gets.
///
/// The month then runs — income and expenses logged as they happen — and the
/// same screen says how the plan is holding up underneath the fields that set
/// it. Keeping both here is the point: the honest moment to change a budget is
/// while you're looking at how the last version of it is going.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = normaliseMonth(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Plan', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: PlanEditorForm(
        month: month,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        header: [
          Text(
            formatMonth(month),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
        ],
        footer: const [
          SizedBox(height: 32),
          _HowItIsGoing(),
        ],
      ),
    );
  }
}

/// The other half of budgeting: whether the plan is being executed.
///
/// Deliberately below the fields rather than above them. The first job of this
/// screen is to let the month be planned; the report is what you consult once
/// there is a plan to report on.
class _HowItIsGoing extends ConsumerWidget {
  const _HowItIsGoing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = normaliseMonth(DateTime.now());
    final reportAsync = ref.watch(planVsActualProvider(month));
    final currency = ref.watch(currencyCodeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How it is going', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Everything you log this month lands here.',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        reportAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Text('Could not load this month: $error'),
          data: (report) => _ProgressCard(report: report, currency: currency),
        ),
        const SizedBox(height: 12),
        _RecurringCard(month: month, currency: currency),
      ],
    );
  }
}

class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({required this.report, required this.currency});

  final PlanVsActual report;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (!report.hasPlan && !report.hasActuals) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Nothing logged yet. Save a plan above, then log income and '
            'expenses as the month goes — this fills in from there.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Day ${report.daysElapsed} of ${report.daysInMonth}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  report.leftToSpendMinor < 0
                      ? '${formatMoney(-report.leftToSpendMinor, currency: currency)} over plan'
                      : '${formatMoney(report.leftToSpendMinor, currency: currency)} left to spend',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: report.leftToSpendMinor < 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            VarianceRow(line: report.income, currency: currency),
            const SizedBox(height: 18),
            VarianceRow(line: report.spend, currency: currency),
            const SizedBox(height: 12),
            const _ProjectionNote(),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  // The report's month picker is how earlier months — and the
                  // plans they were judged against — are reached.
                  ref
                      .read(selectedPlanMonthProvider.notifier)
                      .select(report.month);
                  context.push('/plan/history');
                },
                child: const Text('Bucket by bucket, and past months'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the month lands if nothing changes, split into what is already known
/// and what is only a pace. Silent until both halves can be computed.
class _ProjectionNote extends ConsumerWidget {
  const _ProjectionNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = normaliseMonth(DateTime.now());
    final report = ref.watch(planVsActualProvider(month)).asData?.value;
    final expenses = ref.watch(expensesForMonthProvider(month)).asData?.value;
    final payments = ref.watch(recurringPaymentsProvider).asData?.value;
    final currency = ref.watch(currencyCodeProvider);

    if (report == null || expenses == null || payments == null) {
      return const SizedBox.shrink();
    }

    final projection = MonthProjection.from(
      report: report,
      expenses: expenses,
      payments: payments,
    );
    if (projection.isEmpty || projection.projectedSpendMinor == 0) {
      return const SizedBox.shrink();
    }

    final buffer = StringBuffer(
      'On course to spend '
      '${formatMoney(projection.projectedSpendMinor, currency: currency)}',
    );
    if (projection.committedMinor > 0) {
      buffer.write(
        ', including '
        '${formatMoney(projection.committedMinor, currency: currency)} '
        'of recurring still due',
      );
    }
    if (projection.plannedSpendMinor > 0) {
      final gap = projection.projectedVsPlanMinor;
      buffer.write(
        gap > 0
            ? ' — ${formatMoney(gap, currency: currency)} over plan'
            : ' — ${formatMoney(-gap, currency: currency)} under plan',
      );
    }
    buffer.write('.');

    return Text(
      buffer.toString(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Fixed obligations are the part of the budget that is decided before the
/// month starts, so the budgeting screen is where the link to them belongs.
class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({required this.month, required this.currency});

  final DateTime month;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(planVsActualProvider(month)).asData?.value;
    final expenses = ref.watch(expensesForMonthProvider(month)).asData?.value;
    final payments = ref.watch(recurringPaymentsProvider).asData?.value;

    final String subtitle;
    if (payments == null || payments.isEmpty) {
      subtitle = 'None yet — rent and subscriptions belong in the budget';
    } else if (report == null || expenses == null) {
      subtitle = '${payments.length} '
          '${payments.length == 1 ? 'payment' : 'payments'}';
    } else {
      final projection = MonthProjection.from(
        report: report,
        expenses: expenses,
        payments: payments,
      );
      subtitle = '${payments.length} '
          '${payments.length == 1 ? 'payment' : 'payments'} · '
          '${formatMoney(projection.committedMinor, currency: currency)} '
          'still due this month';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          Icons.event_repeat_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(
          'Recurring commitments',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        // Lives under transactions now; this is the way in from the side that
        // cares about it as a budget input.
        onTap: () => context.push('/transactions?tab=recurring'),
      ),
    );
  }
}
