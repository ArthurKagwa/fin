import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:fintrack/features/planning/data/plan_repository.dart';
import 'package:fintrack/features/planning/presentation/plan_controller.dart';
import 'package:fintrack/features/planning/presentation/widgets/bullet_bar.dart';
import 'package:fintrack/features/planning/presentation/widgets/plan_summary.dart';
import 'package:fintrack/features/planning/presentation/widgets/variance_style.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/recurring/application/recurring_payment.dart';
import 'package:fintrack/features/recurring/data/recurring_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Freeze this month's plan the first time the dashboard opens, so a later
    // edit to a bucket's default can't rewrite what was planned for it.
    // Deliberately not awaited: the report falls back to bucket defaults if
    // this fails, so it must never gate the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(planControllerProvider.notifier).ensureCurrentMonth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync =
        ref.watch(planVsActualProvider(normaliseMonth(DateTime.now())));

    return Scaffold(
      appBar: AppBar(
        title: Text('Home', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load your dashboard: $error')),
        data: (report) {
          if (report.buckets.isEmpty) {
            return _EmptyDashboard(
              onCreateBucket: () => context.push('/buckets'),
            );
          }
          return _DashboardBody(report: report);
        },
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.onCreateBucket});

  final VoidCallback onCreateBucket;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No buckets yet', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Create buckets, then log money in — your dashboard fills in from there.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onCreateBucket, child: const Text('Create buckets')),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.report});

  final PlanVsActual report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentExpensesAsync = ref.watch(recentExpensesProvider);
    final upcomingAsync = ref.watch(upcomingOccurrencesProvider);

    // The report ranks by variance so the biggest miss surfaces first; here the
    // user's own order wins. Cards that reshuffle every time you log an expense
    // make the dashboard impossible to build muscle memory for.
    final bucketsInUserOrder = [...report.buckets]
      ..sort((a, b) => a.bucket.sortOrder.compareTo(b.bucket.sortOrder));

    final unallocated = ref.watch(unallocatedMinorProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        if (unallocated > 0) ...[
          _UnallocatedBanner(amountMinor: unallocated),
          const SizedBox(height: 20),
        ],
        _PlanVsActualCard(report: report),
        const SizedBox(height: 24),
        Text('Buckets', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final bucket in bucketsInUserOrder) ...[
          _BucketCard(bucketLine: bucket),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        upcomingAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (occurrences) =>
              occurrences.isEmpty ? const SizedBox.shrink() : _UpcomingCard(occurrences: occurrences),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent entries', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => context.push('/transactions'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        recentExpensesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load recent entries: $error'),
          data: (allExpenses) {
            final recent = allExpenses.take(5).toList();
            if (recent.isEmpty) {
              return Text(
                'No expenses logged yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              );
            }
            return Card(
              child: Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    _ExpenseRow(
                      expense: recent[i],
                      bucketName: _bucketName(recent[i].bucketId),
                    ),
                    if (i != recent.length - 1)
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _bucketName(String bucketId) {
    for (final b in report.buckets) {
      if (b.bucket.id == bucketId) return b.bucket.name;
    }
    return 'Unknown bucket';
  }
}

class _UnallocatedBanner extends ConsumerWidget {
  const _UnallocatedBanner({required this.amountMinor});

  final int amountMinor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyCodeProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/money-in'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.savings_outlined, color: colorScheme.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${formatMoney(amountMinor, currency: currency)} not yet given a job — allocate it',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "am I OK this month?" card. Tapping through answers "where is it going
/// wrong?" on the full report.
class _PlanVsActualCard extends ConsumerWidget {
  const _PlanVsActualCard({required this.report});

  final PlanVsActual report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyCodeProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(selectedPlanMonthProvider.notifier).select(report.month);
          context.push('/plan/history');
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlanSummary(report: report, currency: currency),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    report.hasPlan ? 'See the full picture' : 'Set your plan',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BucketCard extends ConsumerWidget {
  const _BucketCard({required this.bucketLine});

  final BucketVarianceLine bucketLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyCodeProvider);
    final line = bucketLine.line;
    final style = varianceStyleFor(context, line, currency: currency);
    final remainingMinor = line.plannedMinor - line.actualMinor;
    final isOverspent = remainingMinor < 0;
    final goalMinor = bucketLine.bucket.goalMinor;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/buckets/${bucketLine.bucket.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          bucketLine.bucket.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatMoney(line.actualMinor, currency: currency)} spent of ${formatMoney(line.plannedMinor, currency: currency)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(remainingMinor, currency: currency),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: isOverspent ? colorScheme.error : colorScheme.onSurface,
                            ),
                      ),
                      Text(
                        'remaining',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BulletBar(
                plannedMinor: line.plannedMinor,
                actualMinor: line.actualMinor,
                fillColor: style.color,
                paceMarker: line.monthProgress,
                height: 6,
                semanticLabel: varianceSemanticLabel(line, currency: currency),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(style.icon, size: 14, color: style.color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      style.label,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: style.color),
                    ),
                  ),
                ],
              ),
              if (goalMinor != null) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.15)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 16, color: colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'Goal: ${formatMoney(goalMinor, currency: currency)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Spacer(),
                    // balanceMinor is the running envelope balance — it never
                    // resets between months, so it doubles as goal progress
                    // with no separate carry-over figure to compute.
                    Text(
                      '${(bucketLine.bucket.balanceMinor / goalMinor * 100).clamp(0, 100).round()}%',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.secondary,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard({required this.occurrences});

  final List<Occurrence> occurrences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyCodeProvider);
    final total = occurrences.fold<int>(0, (sum, o) => sum + o.expectedMinor);
    return Card(
      clipBehavior: Clip.antiAlias,
      // The chevron was here before the tap was. An affordance that does
      // nothing reads as a broken app, not as a decoration.
      child: InkWell(
        onTap: () => context.push('/transactions?tab=recurring'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.event_repeat_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${occurrences.length} charges in the next 14 days',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'Totaling ${formatMoney(total, currency: currency)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense, required this.bucketName});

  final Expense expense;
  final String bucketName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyCodeProvider);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHigh,
        foregroundColor: colorScheme.onSurfaceVariant,
        child: const Icon(Icons.receipt_long_outlined, size: 18),
      ),
      title: Text(expense.payee ?? bucketName),
      subtitle: Text('$bucketName · ${relativeDate(expense.occurredOn)}'),
      trailing: Text(
        '-${formatMoney(expense.amountMinor, currency: currency)}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
