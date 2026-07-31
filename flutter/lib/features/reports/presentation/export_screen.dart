import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:fintrack/features/income/data/income_repository.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/data/plan_repository.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/reports/application/monthly_statement.dart';
import 'package:fintrack/features/reports/presentation/export_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pick a month, see exactly what will be in the file, then share it.
///
/// The preview matters: an export that silently produces an empty document is
/// worse than one that refuses, so the button reflects what's actually there.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late DateTime _month = normaliseMonth(DateTime.now());

  bool get _canGoForward => _month.isBefore(normaliseMonth(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(planVsActualProvider(_month));
    final expensesAsync = ref.watch(expensesForMonthProvider(_month));
    final incomeAsync = ref.watch(incomeEventsForMonthProvider(_month));
    final currency = ref.watch(currencyCodeProvider);
    final isSharing = ref.watch(exportControllerProvider).isLoading;

    ref.listen(exportControllerProvider, (_, next) {
      if (next is AsyncError && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export: ${next.error}')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: Column(
        children: [
          _MonthPicker(
            month: _month,
            canGoForward: _canGoForward,
            onPrevious: () => setState(
              () => _month = DateTime(_month.year, _month.month - 1),
            ),
            onNext: _canGoForward
                ? () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    )
                : null,
          ),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorBody(error: error),
              data: (report) {
                final expenses = expensesAsync.asData?.value;
                final income = incomeAsync.asData?.value;
                if (expenses == null || income == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final statement = MonthlyStatement(
                  report: report,
                  expenses: expenses,
                  incomeEvents: income,
                  currency: currency,
                  generatedAt: DateTime.now(),
                );
                return _Preview(
                  statement: statement,
                  isSharing: isSharing,
                  onShare: () => ref
                      .read(exportControllerProvider.notifier)
                      .shareStatement(statement),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.month,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
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
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.statement,
    required this.isSharing,
    required this.onShare,
  });

  final MonthlyStatement statement;
  final bool isSharing;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final report = statement.report;
    final currency = statement.currency;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statement.fileName,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PreviewLine(
                  label: 'Income received',
                  value: formatMoney(report.income.actualMinor, symbol: currency),
                ),
                _PreviewLine(
                  label: 'Money spent',
                  value: formatMoney(report.spend.actualMinor, symbol: currency),
                ),
                _PreviewLine(
                  label: 'Income entries',
                  value: '${statement.incomeEvents.length}',
                ),
                _PreviewLine(
                  label: 'Expense entries',
                  value: '${statement.expenses.length}',
                ),
                _PreviewLine(
                  label: 'Buckets covered',
                  value: '${statement.bucketLines.length}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'The statement covers the summary, money in by source, spend by '
          'bucket and every transaction in the month.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (!report.plan.isSnapshot) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No plan was recorded for this month, so planned figures come '
                  'from your current bucket amounts. The statement says so too.',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: statement.isEmpty || isSharing ? null : onShare,
          icon: isSharing
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share),
          label: Text(isSharing ? 'Preparing...' : 'Share PDF'),
        ),
        if (statement.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'There is nothing recorded for ${formatMonth(statement.month)} yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not load this month: $error'),
      ),
    );
  }
}
