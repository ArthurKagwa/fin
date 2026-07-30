import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/recurring/application/recurring_payment.dart';
import 'package:fintrack/features/recurring/data/recurring_repository.dart';
import 'package:fintrack/features/recurring/presentation/recurring_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(recurringPaymentsProvider);
    final occurrencesAsync = ref.watch(upcomingOccurrencesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Recurring', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load recurring payments: $error')),
        data: (payments) {
          final paymentsById = {for (final p in payments) p.id: p};

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Upcoming', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    'Next 14 days',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              occurrencesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Could not load upcoming charges: $error'),
                data: (occurrences) {
                  if (occurrences.isEmpty) {
                    return Text(
                      'No upcoming charges — add recurring payments.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    );
                  }
                  return Column(
                    children: [
                      for (final occurrence in occurrences)
                        if (paymentsById[occurrence.recurringPaymentId] != null)
                          _OccurrenceRow(
                            occurrence: occurrence,
                            payment: paymentsById[occurrence.recurringPaymentId]!,
                          ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('All recurring', style: Theme.of(context).textTheme.titleLarge),
                  TextButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No recurring payments yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                for (final payment in payments) _RecurringRow(payment: payment),
            ],
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _CreateRecurringDialog(),
    );
  }
}

class _CreateRecurringDialog extends ConsumerStatefulWidget {
  const _CreateRecurringDialog();

  @override
  ConsumerState<_CreateRecurringDialog> createState() => _CreateRecurringDialogState();
}

class _CreateRecurringDialogState extends ConsumerState<_CreateRecurringDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _bucketId;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  final DateTime _startOn = DateTime.now();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bucketsAsync = ref.watch(activeBucketsProvider);

    return AlertDialog(
      title: const Text('New recurring payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            bucketsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Could not load buckets: $error'),
              data: (buckets) {
                if (_bucketId == null && buckets.isNotEmpty) {
                  _bucketId = buckets.first.id;
                }
                return DropdownButtonFormField<String>(
                  initialValue: _bucketId,
                  decoration: const InputDecoration(labelText: 'Bucket'),
                  items: [
                    for (final bucket in buckets)
                      DropdownMenuItem(value: bucket.id, child: Text(bucket.name)),
                  ],
                  onChanged: (value) => setState(() => _bucketId = value),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurringFrequency>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const [
                DropdownMenuItem(value: RecurringFrequency.daily, child: Text('Daily')),
                DropdownMenuItem(value: RecurringFrequency.weekly, child: Text('Weekly')),
                DropdownMenuItem(value: RecurringFrequency.biweekly, child: Text('Every 2 weeks')),
                DropdownMenuItem(value: RecurringFrequency.monthly, child: Text('Monthly')),
                DropdownMenuItem(value: RecurringFrequency.yearly, child: Text('Yearly')),
              ],
              onChanged: (value) => setState(() => _frequency = value ?? _frequency),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final amount = int.tryParse(_amountController.text.replaceAll(',', ''));
            if (name.isEmpty || amount == null || amount <= 0 || _bucketId == null) return;
            ref.read(recurringControllerProvider.notifier).create(
                  name: name,
                  bucketId: _bucketId!,
                  frequency: _frequency,
                  amountMinor: amount,
                  startOn: _startOn,
                );
            Navigator.of(context).pop();
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _OccurrenceRow extends ConsumerWidget {
  const _OccurrenceRow({required this.occurrence, required this.payment});

  final Occurrence occurrence;
  final RecurringPayment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyCodeProvider);
    final isOverdue = occurrence.dueOn.isBefore(DateTime.now()) &&
        occurrence.status == OccurrenceStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(payment.name, style: Theme.of(context).textTheme.titleMedium),
                      if (isOverdue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Overdue',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${formatMoney(occurrence.expectedMinor, symbol: currency)} · due ${relativeDate(occurrence.dueOn)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => ref.read(recurringControllerProvider.notifier).skip(occurrence.id),
              child: const Text('Skip'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => ref.read(recurringControllerProvider.notifier).confirm(occurrence.id),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringRow extends ConsumerWidget {
  const _RecurringRow({required this.payment});

  final RecurringPayment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyCodeProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHigh,
        foregroundColor: colorScheme.onSurfaceVariant,
        child: const Icon(Icons.repeat, size: 18),
      ),
      title: Text(payment.name),
      subtitle: Text(_frequencyLabel(payment.frequency)),
      trailing: Text(
        formatMoney(payment.currentAmountMinor, symbol: currency),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }

  String _frequencyLabel(RecurringFrequency frequency) {
    return switch (frequency) {
      RecurringFrequency.daily => 'Daily',
      RecurringFrequency.weekly => 'Weekly',
      RecurringFrequency.biweekly => 'Every 2 weeks',
      RecurringFrequency.monthly => 'Monthly',
      RecurringFrequency.yearly => 'Yearly',
      RecurringFrequency.custom => 'Custom',
    };
  }
}
