import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/trends/application/spend_trend.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _monthsShown = 6;

/// Spend over the last 6 months as a bar chart — the one piece of
/// time-series visualization in the app; everything else is a single
/// month's snapshot.
class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyCodeProvider);
    final months = lastMonths(_monthsShown, now: DateTime.now());

    final monthlyAsyncs = [
      for (final month in months) ref.watch(expensesForMonthProvider(month)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Spending trend')),
      body: monthlyAsyncs.any((a) => a.isLoading)
          ? const Center(child: CircularProgressIndicator())
          : monthlyAsyncs.any((a) => a.hasError)
              ? Center(
                  child: Text(
                    'Could not load trend: ${monthlyAsyncs.firstWhere((a) => a.hasError).error}',
                  ),
                )
              : _buildChart(
                  context,
                  buildSpendTrend(
                    months: months,
                    expensesByMonth: [for (final a in monthlyAsyncs) a.requireValue],
                  ),
                  currency,
                  theme,
                ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    List<MonthlySpend> trend,
    String currency,
    ThemeData theme,
  ) {
    if (trend.every((m) => m.totalMinor == 0)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Log some expenses to see how spending moves month to month.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final maxMinor = trend.map((m) => m.totalMinor).reduce((a, b) => a > b ? a : b);
    final maxY = maxMinor == 0 ? 1.0 : maxMinor * 1.2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 20, 24),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trend.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _shortMonth(trend[index].month),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                formatMoney(trend[groupIndex].totalMinor, currency: currency),
                theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.onInverseSurface),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < trend.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: trend[i].totalMinor.toDouble(),
                    color: theme.colorScheme.primary,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _shortMonth(DateTime month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month.month - 1];
  }
}
