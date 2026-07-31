import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/allocations/data/allocation_repository.dart';
import 'package:fintrack/features/allocations/presentation/allocate_sheet.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/income/data/income_repository.dart';
import 'package:fintrack/features/income/presentation/add_income_sheet.dart';
import 'package:fintrack/features/income/presentation/income_controller.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IncomeListScreen extends ConsumerWidget {
  const IncomeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(incomeEventsProvider);
    final currency = ref.watch(currencyCodeProvider);
    final unallocated = ref.watch(unallocatedMinorProvider);
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
                        formatMoney(totalThisMonth, currency: currency),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (unallocated > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.savings_outlined, color: colorScheme.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${formatMoney(unallocated, currency: currency)} not yet '
                          'given a job — tap an entry below to allocate it.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                for (final event in events)
                  _IncomeRow(
                    event: event,
                    currency: currency,
                    onDelete: () => _delete(context, ref, event, currency),
                  ),
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

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    IncomeEvent event,
    String currency,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(incomeControllerProvider.notifier).deleteIncome(event.id);
    if (!context.mounted) return;
    if (ref.read(incomeControllerProvider).hasError) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete. Try again.')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${formatMoney(event.amountMinor, currency: currency)} from '
          '${event.source} deleted',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              ref.read(incomeControllerProvider.notifier).restoreIncome(event.id),
        ),
      ),
    );
  }
}

class _IncomeRow extends ConsumerWidget {
  const _IncomeRow({
    required this.event,
    required this.currency,
    required this.onDelete,
  });

  final IncomeEvent event;
  final String currency;
  final VoidCallback onDelete;

  Future<bool> _confirmDismiss(BuildContext context, WidgetRef ref) async {
    final hasAllocations =
        await ref.read(allocationRepositoryProvider).hasAllocationsForIncomeEvent(event.id);
    if (!context.mounted) return false;
    if (hasAllocations) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This has already been allocated — unallocate it first.'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final hasAllocations =
        await ref.read(allocationRepositoryProvider).hasAllocationsForIncomeEvent(event.id);
    if (!context.mounted) return;
    if (hasAllocations) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This has already been allocated and can\'t be edited.'),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddIncomeSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDismiss(context, ref),
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _handleTap(context, ref),
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
                      '+${formatMoney(event.amountMinor, currency: currency)}',
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
                      _MiniStat(label: 'Gross', value: formatMoney(event.grossMinor!, currency: currency)),
                      _MiniStat(
                        label: 'Deductions',
                        value: formatMoney(event.deductionsTotalMinor, currency: currency),
                      ),
                      _MiniStat(
                        label: 'Take-home',
                        value: formatMoney(event.amountMinor, currency: currency),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => AllocateSheet(source: event),
                    ),
                    icon: const Icon(Icons.savings_outlined, size: 16),
                    label: const Text('Allocate'),
                  ),
                ),
              ],
            ),
          ),
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
