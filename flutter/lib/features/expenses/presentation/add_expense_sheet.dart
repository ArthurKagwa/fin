import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/core/widgets/date_chip.dart';
import 'package:fintrack/core/widgets/money_field.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/expenses/presentation/expense_controller.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _bucketId;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = moneyFromField(_amountController);
    if (amount <= 0) {
      setState(() => _error = 'Amount must be more than zero');
      return;
    }
    final buckets = ref.read(activeBucketsProvider).asData?.value ?? const [];
    final bucketId = _bucketId ?? (buckets.isEmpty ? null : buckets.first.id);
    if (bucketId == null) {
      setState(() => _error = 'Pick a bucket');
      return;
    }

    final note = _noteController.text.trim();
    final created = await ref.read(expenseControllerProvider.notifier).addExpense(
          bucketId: bucketId,
          amountMinor: amount,
          occurredOn: _date,
          payee: note.isEmpty ? null : note,
        );

    if (!mounted) return;
    if (created == null) {
      setState(() => _error = 'Could not save. Try again.');
      return;
    }

    final currency = ref.read(currencyCodeProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${formatMoney(amount, currency: currency)} saved'),
        duration: const Duration(seconds: 5),
        // The snackbar was already sitting here for five seconds doing
        // nothing; catching a mistyped amount in the moment is the single
        // cheapest correction the app can offer.
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref
              .read(expenseControllerProvider.notifier)
              .deleteExpense(created.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bucketsAsync = ref.watch(activeBucketsProvider);
    final currency = ref.watch(currencyCodeProvider);
    final isLoading = ref.watch(expenseControllerProvider).isLoading;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Add Expense', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            MoneyField(
              controller: _amountController,
              currency: currency,
              autofocus: true,
              large: true,
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: DateChip(
                date: _date,
                onChanged: (picked) => setState(() => _date = picked),
              ),
            ),
            const SizedBox(height: 24),
            Text('Bucket', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            bucketsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Could not load buckets: $error'),
              data: (buckets) {
                if (buckets.isEmpty) {
                  return Text(
                    'Create a bucket first to log an expense.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  );
                }
                // Resolved rather than assigned: writing to state during build
                // makes rebuilds unpredictable, and the default is only ever a
                // display concern — `_save` resolves it the same way.
                final selectedId = _bucketId ?? buckets.first.id;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final bucket in buckets)
                      ChoiceChip(
                        label: Text(bucket.name),
                        selected: selectedId == bucket.id,
                        onSelected: (_) => setState(() => _bucketId = bucket.id),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Payee / note (optional)',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isLoading ? null : _save,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
