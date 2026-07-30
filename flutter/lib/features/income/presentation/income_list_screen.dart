import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/income/data/income_repository.dart';
import 'package:fintrack/features/income/presentation/add_income_sheet.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IncomeListScreen extends ConsumerWidget {
  const IncomeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(incomeEventsProvider);
    final currency = ref.watch(currencyCodeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Money In', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load income: $error')),
        data: (events) {
          final now = DateTime.now();
          final totalThisMonth = events
              .where((e) => e.occurredOn.year == now.year && e.occurredOn.month == now.month)
              .fold<int>(0, (sum, e) => sum + e.amountMinor);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This month',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatMoney(totalThisMonth, symbol: currency),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Income', style: Theme.of(context).textTheme.titleLarge),
                  TextButton.icon(
                    onPressed: () => _showAddSheet(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No income logged yet — add your first paycheque or payment.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                for (final event in events) _IncomeRow(event: event, currency: currency),
            ],
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddIncomeSheet(),
    );
  }
}

class _IncomeRow extends StatelessWidget {
  const _IncomeRow({required this.event, required this.currency});

  final IncomeEvent event;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.secondary,
                  child: Icon(
                    event.isPaycheque ? Icons.work_outline : Icons.attach_money,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.source, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        relativeDate(event.occurredOn),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+${formatMoney(event.amountMinor, symbol: currency)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.secondary,
                      ),
                ),
              ],
            ),
            if (event.isPaycheque && event.grossMinor != null) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.15)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniStat(label: 'Gross', value: formatMoney(event.grossMinor!, symbol: currency)),
                  _MiniStat(
                    label: 'Deductions',
                    value: formatMoney(event.deductionsTotalMinor, symbol: currency),
                  ),
                  _MiniStat(
                    label: 'Take-home',
                    value: formatMoney(event.amountMinor, symbol: currency),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
