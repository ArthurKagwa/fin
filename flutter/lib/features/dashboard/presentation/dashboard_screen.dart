import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/dashboard/application/dashboard_summary.dart';
import 'package:fintrack/features/dashboard/data/dashboard_repository.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/recurring/application/recurring_payment.dart';
import 'package:fintrack/features/recurring/data/recurring_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Home', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load your dashboard: $error')),
        data: (summary) {
          if (summary.buckets.isEmpty) {
            return _EmptyDashboard(onCreateBucket: () => context.push('/buckets'));
          }
          return _DashboardBody(summary: summary);
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
  const _DashboardBody({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentExpensesAsync = ref.watch(recentExpensesProvider);
    final upcomingAsync = ref.watch(upcomingOccurrencesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        if (summary.unallocatedMinor > 0) ...[
          _UnallocatedBanner(amountMinor: summary.unallocatedMinor),
          const SizedBox(height: 20),
        ],
        _PaceHeader(summary: summary),
        const SizedBox(height: 24),
        Text('Buckets', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final bucket in summary.buckets) ...[
          _BucketCard(bucketSummary: bucket),
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
        Text('Recent entries', style: Theme.of(context).textTheme.titleLarge),
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
    for (final b in summary.buckets) {
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.savings_outlined, color: colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${formatMoney(amountMinor, symbol: currency)} not yet given a job — allocate',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Icon(Icons.chevron_right, color: colorScheme.secondary),
        ],
      ),
    );
  }
}

class _PaceHeader extends StatelessWidget {
  const _PaceHeader({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final percentElapsed = (summary.monthProgress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Day ${summary.daysElapsed} of ${summary.daysInMonth}',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 4),
        Text(
          '$percentElapsed% of the month gone',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: summary.monthProgress.clamp(0, 1),
            minHeight: 6,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _BucketCard extends ConsumerWidget {
  const _BucketCard({required this.bucketSummary});

  final BucketSummary bucketSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyCodeProvider);
    final planned = bucketSummary.plannedMinor;
    final spentRatio = planned > 0 ? bucketSummary.spentThisMonthMinor / planned : 0.0;
    final isOverspent = bucketSummary.balanceMinor < 0;

    final Color paceColor;
    final String paceLabel;
    if (isOverspent) {
      paceColor = colorScheme.error;
      paceLabel = 'Overspent';
    } else if (spentRatio > 0.85) {
      paceColor = const Color(0xFFB8860B);
      paceLabel = 'Near limit';
    } else {
      paceColor = colorScheme.secondary;
      paceLabel = 'On track';
    }

    final goalMinor = bucketSummary.bucket.goalMinor;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/buckets/${bucketSummary.bucket.id}'),
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
                          bucketSummary.bucket.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatMoney(bucketSummary.spentThisMonthMinor, symbol: currency)} spent of ${formatMoney(planned, symbol: currency)}',
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
                        formatMoney(bucketSummary.balanceMinor, symbol: currency),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: spentRatio.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(paceColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    isOverspent ? Icons.error_outline : Icons.check_circle_outline,
                    size: 14,
                    color: paceColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    paceLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: paceColor),
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
                      'Goal: ${formatMoney(goalMinor, symbol: currency)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${((bucketSummary.carriedOverMinor / goalMinor) * 100).clamp(0, 100).round()}%',
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
                    'Totaling ${formatMoney(total, symbol: currency)}',
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
        '-${formatMoney(expense.amountMinor, symbol: currency)}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
