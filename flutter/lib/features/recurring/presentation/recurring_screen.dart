import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/recurring/application/recurring_payment.dart';
import 'package:fintrack/features/recurring/data/recurring_repository.dart';
import 'package:fintrack/features/recurring/presentation/recurring_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                    onPressed: () => context.push('/recurring/new'),
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
                    'No recurring payments yet — add rent, subscriptions or '
                    'school fees and they show up here before they land.',
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
                    '${formatMoney(occurrence.expectedMinor, currency: currency)} · due ${relativeDate(occurrence.dueOn)}',
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
      onTap: () => context.push('/recurring/${payment.id}/edit'),
      leading: CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHigh,
        foregroundColor: colorScheme.onSurfaceVariant,
        child: const Icon(Icons.repeat, size: 18),
      ),
      title: Text(payment.name),
      subtitle: Text(_frequencyLabel(payment.frequency)),
      trailing: Text(
        formatMoney(payment.currentAmountMinor, currency: currency),
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
