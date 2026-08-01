import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:fintrack/features/planning/application/month_projection.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/data/plan_repository.dart';
import 'package:fintrack/features/planning/presentation/plan_controller.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/recurring/data/recurring_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Where the month is heading, and everything that decides it.
///
/// The dashboard answers "am I OK today?" and the transactions list answers
/// "what happened?". This is the forward-looking one: what the month lands on
/// if nothing changes, and the three inputs — expected income, planned spend,
/// recurring commitments — that move that number.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = normaliseMonth(DateTime.now());
    final reportAsync = ref.watch(planVsActualProvider(month));
    final expensesAsync = ref.watch(expensesForMonthProvider(month));
    final paymentsAsync = ref.watch(recurringPaymentsProvider);
    final currency = ref.watch(currencyCodeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Plan', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load your plan: $error'),
          ),
        ),
        data: (report) {
          final expenses = expensesAsync.asData?.value;
          final payments = paymentsAsync.asData?.value;
          // Both feed the split between committed and everyday spend. Drawing
          // the projection before they land would show a number that jumps the
          // moment they arrive.
          if (expenses == null || payments == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final projection = MonthProjection.from(
            report: report,
            expenses: expenses,
            payments: payments,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              Text(
                formatMonth(month),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              if (projection.isEmpty)
                _NoPlanYet(onSetPlan: () => _openEditor(context, ref, month))
              else
                _ProjectionCard(projection: projection, currency: currency),
              const SizedBox(height: 28),
              Text(
                'Configure',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'The projection is only ever as good as these three.',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              _ConfigCard(
                children: [
                  _ConfigRow(
                    icon: Icons.edit_outlined,
                    title: 'Expected income',
                    subtitle: projection.expectedIncomeMinor > 0
                        ? '${formatMoney(projection.expectedIncomeMinor, currency: currency)} expected this month'
                        : 'Not set — the projection has nothing to land against',
                    onTap: () => _openEditor(context, ref, month),
                  ),
                  _ConfigRow(
                    icon: Icons.flag_outlined,
                    title: 'Planned spend',
                    subtitle: projection.plannedSpendMinor > 0
                        ? '${formatMoney(projection.plannedSpendMinor, currency: currency)} planned across your buckets'
                        : 'Not set — plan what each bucket should spend',
                    onTap: () => _openEditor(context, ref, month),
                  ),
                  _ConfigRow(
                    icon: Icons.event_repeat_outlined,
                    title: 'Recurring commitments',
                    subtitle: payments.isEmpty
                        ? 'None yet — rent and subscriptions sharpen the forecast'
                        : '${payments.length} ${payments.length == 1 ? 'payment' : 'payments'} · '
                            '${formatMoney(projection.committedMinor, currency: currency)} still due this month',
                    // Lives under transactions now; this is the way in from the
                    // side that cares about it as a forecast input.
                    onTap: () => context.push('/transactions?tab=recurring'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ConfigCard(
                children: [
                  _ConfigRow(
                    icon: Icons.history,
                    title: 'Plan vs actual',
                    subtitle: 'How this month and past months landed',
                    onTap: () {
                      ref
                          .read(selectedPlanMonthProvider.notifier)
                          .select(DateTime.now());
                      context.push('/plan/history');
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, DateTime month) {
    // The editor works on whichever month the report is showing, so point it
    // at this one before opening it.
    ref.read(selectedPlanMonthProvider.notifier).select(month);
    context.push('/plan/edit');
  }
}

/// The headline: what the month ends with, and the arithmetic behind it.
class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.projection, required this.currency});

  final MonthProjection projection;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final leftover = projection.projectedLeftoverMinor;
    final isShort = leftover < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isShort ? 'Projected shortfall' : 'Projected to be left over',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatMoney(leftover.abs(), currency: currency),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: isShort ? colorScheme.error : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${projection.daysRemaining} days left',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Line(
              label: 'Spent so far',
              amountMinor: projection.spentMinor,
              currency: currency,
            ),
            const SizedBox(height: 10),
            _Line(
              label: 'Recurring still due',
              amountMinor: projection.committedMinor,
              currency: currency,
              // The exact half of the forecast: these are dated, known amounts,
              // not an extrapolation.
              note: 'known',
            ),
            const SizedBox(height: 10),
            _Line(
              label: 'Everyday spend to come',
              amountMinor: projection.variableForecastMinor,
              currency: currency,
              note: projection.runRateIsMeaningful ? 'at this pace' : 'early estimate',
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.15)),
            const SizedBox(height: 14),
            _Line(
              label: 'Projected spend',
              amountMinor: projection.projectedSpendMinor,
              currency: currency,
              emphasised: true,
            ),
            const SizedBox(height: 10),
            _Line(
              label: 'Money in expected',
              amountMinor: projection.projectedIncomeMinor,
              currency: currency,
              emphasised: true,
            ),
            if (projection.plannedSpendMinor > 0) ...[
              const SizedBox(height: 16),
              _AgainstPlan(projection: projection, currency: currency),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgainstPlan extends StatelessWidget {
  const _AgainstPlan({required this.projection, required this.currency});

  final MonthProjection projection;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gap = projection.projectedVsPlanMinor;
    final isOver = gap > 0;
    final colour = isOver ? colorScheme.error : colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isOver ? colorScheme.errorContainer : colorScheme.surfaceContainerHigh)
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(isOver ? Icons.info_outline : Icons.check_circle_outline,
              size: 16, color: colour),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOver
                  ? 'That lands ${formatMoney(gap, currency: currency)} over your '
                      '${formatMoney(projection.plannedSpendMinor, currency: currency)} plan.'
                  : 'That lands ${formatMoney(-gap, currency: currency)} under your '
                      '${formatMoney(projection.plannedSpendMinor, currency: currency)} plan.',
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.amountMinor,
    required this.currency,
    this.note,
    this.emphasised = false,
  });

  final String label;
  final int amountMinor;
  final String currency;
  final String? note;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = emphasised
        ? theme.textTheme.bodyMedium
        : theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(child: Text(label, style: labelStyle)),
              if (note != null) ...[
                const SizedBox(width: 6),
                Text(
                  note!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatMoney(amountMinor, currency: currency),
          style: emphasised ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _NoPlanYet extends StatelessWidget {
  const _NoPlanYet({required this.onSetPlan});

  final VoidCallback onSetPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nothing to project yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Set what you expect to earn and what each bucket should spend, '
              'and this shows where the month lands before it gets there.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onSetPlan, child: const Text('Set your plan')),
          ],
        ),
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: colorScheme.outline.withValues(alpha: 0.15),
              ),
          ],
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
