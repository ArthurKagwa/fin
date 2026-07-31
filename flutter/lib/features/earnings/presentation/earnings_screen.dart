import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/earnings/application/earnings_summary.dart';
import 'package:fintrack/features/earnings/presentation/earnings_controller.dart';
import 'package:fintrack/features/earnings/presentation/widgets/split_bar.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// US-23: gross vs take-home by month.
///
/// Leads with the deduction rate rather than either raw total. "You earned
/// 3,000,000" and "you received 2,100,000" are both facts the user already
/// knows; "30% never reaches you, and here is what takes it" is the one that
/// changes anything.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(earningsSummaryProvider);
    final currency = ref.watch(currencyCodeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load your earnings: $error'),
          ),
        ),
        data: (summary) => summary.isEmpty
            ? const _EmptyEarnings()
            : _EarningsBody(summary: summary, currency: currency),
      ),
    );
  }
}

class _EarningsBody extends StatelessWidget {
  const _EarningsBody({required this.summary, required this.currency});

  final EarningsSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topDeductions = summary.deductionsAcrossAllMonths.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _AllTimeSummary(summary: summary, currency: currency),
          ),
        ),
        if (topDeductions.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('What takes it', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (var i = 0; i < topDeductions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _DeductionLine(
                      deduction: topDeductions[i],
                      grossMinor: summary.grossTotalMinor,
                      currency: currency,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Text('By month', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final month in summary.months) ...[
          _MonthCard(month: month, currency: currency),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AllTimeSummary extends StatelessWidget {
  const _AllTimeSummary({required this.summary, required this.currency});

  final EarningsSummary summary;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ratePercent = (summary.effectiveDeductionRate * 100).round();
    final change = summary.takeHomeChangeMinor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary.deductionsTotalMinor > 0
              ? 'Deductions take'
              : 'Total take-home',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          summary.deductionsTotalMinor > 0
              ? '$ratePercent%'
              : formatMoney(summary.takeHomeTotalMinor, symbol: currency),
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: 4),
        Text(
          summary.deductionsTotalMinor > 0
              ? 'of everything you have earned across '
                  '${summary.months.length} ${summary.months.length == 1 ? 'month' : 'months'}'
              : 'across ${summary.months.length} '
                  '${summary.months.length == 1 ? 'month' : 'months'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        SplitBar(
          primaryMinor: summary.takeHomeTotalMinor,
          secondaryMinor: summary.deductionsTotalMinor,
          primaryColor: colorScheme.secondary,
          secondaryColor: colorScheme.error.withValues(alpha: 0.55),
          height: 10,
          semanticLabel:
              '${formatMoney(summary.takeHomeTotalMinor, symbol: currency)} take-home, '
              '${formatMoney(summary.deductionsTotalMinor, symbol: currency)} deducted, '
              'from ${formatMoney(summary.grossTotalMinor, symbol: currency)} gross',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Legend(
              color: colorScheme.secondary,
              label: 'Take-home',
              value: formatMoney(summary.takeHomeTotalMinor, symbol: currency),
            ),
            const SizedBox(width: 20),
            _Legend(
              color: colorScheme.error.withValues(alpha: 0.55),
              label: 'Deductions',
              value: formatMoney(summary.deductionsTotalMinor, symbol: currency),
            ),
          ],
        ),
        if (change != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: change >= 0 ? colorScheme.secondary : colorScheme.error,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${formatMoney(change.abs(), symbol: currency)} '
                  '${change >= 0 ? 'more' : 'less'} take-home than the month before',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: change >= 0 ? colorScheme.secondary : colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DeductionLine extends StatelessWidget {
  const _DeductionLine({
    required this.deduction,
    required this.grossMinor,
    required this.currency,
  });

  final DeductionTotal deduction;
  final int grossMinor;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent =
        grossMinor > 0 ? (deduction.amountMinor / grossMinor * 100).round() : 0;

    return Row(
      children: [
        Expanded(
          child: Text(deduction.label, style: theme.textTheme.bodyMedium),
        ),
        Text(
          '$percent%',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatMoney(deduction.amountMinor, symbol: currency),
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month, required this.currency});

  final EarningsMonth month;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
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
                        formatMonth(month.month),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        month.hasDeductions
                            ? '${formatMoney(month.grossMinor, symbol: currency)} gross'
                            : 'No deductions recorded',
                        style: theme.textTheme.bodySmall?.copyWith(
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
                      formatMoney(month.takeHomeMinor, symbol: currency),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.secondary,
                      ),
                    ),
                    Text(
                      'take-home',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (month.hasDeductions) ...[
              const SizedBox(height: 12),
              SplitBar(
                primaryMinor: month.takeHomeMinor,
                secondaryMinor: month.deductionsMinor,
                primaryColor: colorScheme.secondary,
                secondaryColor: colorScheme.error.withValues(alpha: 0.55),
                height: 6,
                semanticLabel:
                    '${(month.deductionRate * 100).round()}% deducted in '
                    '${formatMonth(month.month)}',
              ),
              const SizedBox(height: 8),
              Text(
                '${(month.deductionRate * 100).round()}% deducted '
                '(${formatMoney(month.deductionsMinor, symbol: currency)})',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              for (final deduction in month.deductions) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        deduction.label,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    Text(
                      formatMoney(deduction.amountMinor, symbol: currency),
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.labelLarge),
      ],
    );
  }
}

class _EmptyEarnings extends StatelessWidget {
  const _EmptyEarnings();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No earnings yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Log a paycheque with its gross amount and deductions, and this '
              'shows where the difference goes.',
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
