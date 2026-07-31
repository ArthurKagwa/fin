import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/core/widgets/date_chip.dart';
import 'package:fintrack/core/widgets/money_field.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/recurring/application/recurring_payment.dart';
import 'package:fintrack/features/recurring/presentation/recurring_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Creating a recurring payment.
///
/// Promoted from a cramped dialog whose Create button silently returned on
/// invalid input — no message, no state change, indistinguishable from a bug.
/// A screen also has room for the start date, which the dialog hardcoded to
/// today, making "rent, due on the 1st" impossible to express.
class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key});

  @override
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _bucketId;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  DateTime _startOn = DateTime.now();

  String? _nameError;
  String? _amountError;
  String? _bucketError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final buckets = ref.read(activeBucketsProvider).asData?.value ?? const [];
    final name = _nameController.text.trim();
    final amount = moneyFromField(_amountController);
    final bucketId = _bucketId ?? (buckets.isEmpty ? null : buckets.first.id);

    // Every failure now names its own field. The old dialog had one exit for
    // all of them, and that exit was silence.
    setState(() {
      _nameError = name.isEmpty ? 'Give this payment a name.' : null;
      _amountError = amount <= 0 ? 'Enter an amount more than zero.' : null;
      _bucketError = bucketId == null ? 'Create a bucket first.' : null;
      _formError = null;
    });
    if (_nameError != null || _amountError != null || _bucketError != null) {
      return;
    }

    await ref.read(recurringControllerProvider.notifier).create(
          name: name,
          bucketId: bucketId!,
          frequency: _frequency,
          amountMinor: amount,
          startOn: _startOn,
        );

    if (!mounted) return;
    if (ref.read(recurringControllerProvider).hasError) {
      setState(() => _formError = 'Could not save. Try again.');
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyCodeProvider);
    final bucketsAsync = ref.watch(activeBucketsProvider);
    final isSaving = ref.watch(recurringControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('New recurring payment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Rent, Netflix, school fees',
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 16),
          MoneyField(
            controller: _amountController,
            currency: currency,
            label: 'Amount',
            errorText: _amountError,
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          const SizedBox(height: 16),
          bucketsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Could not load buckets: $error'),
            data: (buckets) {
              if (buckets.isEmpty) {
                return Text(
                  'Create a bucket first — every recurring payment is spent '
                  'from one.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              final selectedId = _bucketId ?? buckets.first.id;
              return DropdownButtonFormField<String>(
                initialValue: selectedId,
                decoration: InputDecoration(
                  labelText: 'Bucket',
                  errorText: _bucketError,
                ),
                items: [
                  for (final bucket in buckets)
                    DropdownMenuItem(
                      value: bucket.id,
                      child: Text(bucket.name),
                    ),
                ],
                onChanged: (value) => setState(() => _bucketId = value),
              );
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RecurringFrequency>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: const [
              DropdownMenuItem(
                value: RecurringFrequency.daily,
                child: Text('Daily'),
              ),
              DropdownMenuItem(
                value: RecurringFrequency.weekly,
                child: Text('Weekly'),
              ),
              DropdownMenuItem(
                value: RecurringFrequency.biweekly,
                child: Text('Every 2 weeks'),
              ),
              DropdownMenuItem(
                value: RecurringFrequency.monthly,
                child: Text('Monthly'),
              ),
              DropdownMenuItem(
                value: RecurringFrequency.yearly,
                child: Text('Yearly'),
              ),
            ],
            onChanged: (value) =>
                setState(() => _frequency = value ?? _frequency),
          ),
          const SizedBox(height: 20),
          Text('Starts on', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'The first charge. Later ones follow from here.',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: DateChip(
              date: _startOn,
              semanticsLabel: 'Change start date',
              // Unlike an expense, a recurring payment is normally set up
              // ahead of its first charge, so the future has to be reachable.
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              onChanged: (picked) => setState(() => _startOn = picked),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'First charge ${relativeDate(_startOn)}.',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            Text(
              _formError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isSaving ? null : _save,
            child: isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
    );
  }
}
