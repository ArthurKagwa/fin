import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/core/widgets/date_chip.dart';
import 'package:fintrack/core/widgets/money_field.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/recurring/application/recurring_payment.dart';
import 'package:fintrack/features/recurring/data/recurring_repository.dart';
import 'package:fintrack/features/recurring/presentation/recurring_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Creating or editing a recurring payment.
///
/// Editing only covers name/bucket — amount changes go through
/// [_addRateChangeDialog] (a new [RatePeriod], preserving history) and
/// stopping the payment goes through [_stopDialog] (`endOn`), because both
/// are meaningfully different actions from "rename this," not a field to
/// blend into one save button.
class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.paymentId});

  final String? paymentId;

  bool get isEditing => paymentId != null;

  @override
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _intervalController = TextEditingController(text: '30');
  String? _bucketId;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  DateTime _startOn = DateTime.now();
  bool _prefilled = false;

  String? _nameError;
  String? _amountError;
  String? _bucketError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _prefill(RecurringPayment payment, String currency) {
    if (_prefilled) return;
    _prefilled = true;
    _nameController.text = payment.name;
    _bucketId = payment.bucketId;
    _frequency = payment.frequency;
    _startOn = payment.startOn;
    _intervalController.text = '${payment.intervalDays ?? 30}';
    setMoneyField(_amountController, payment.currentAmountMinor, currency: currency);
  }

  Future<void> _save() async {
    final buckets = ref.read(activeBucketsProvider).asData?.value ?? const [];
    final name = _nameController.text.trim();
    final amount = moneyFromField(_amountController);
    final bucketId = _bucketId ?? (buckets.isEmpty ? null : buckets.first.id);
    final intervalDays = _frequency == RecurringFrequency.custom
        ? (int.tryParse(_intervalController.text.trim()) ?? 0)
        : null;

    setState(() {
      _nameError = name.isEmpty ? 'Give this payment a name.' : null;
      _amountError = amount <= 0 ? 'Enter an amount more than zero.' : null;
      _bucketError = bucketId == null ? 'Create a bucket first.' : null;
      _formError = _frequency == RecurringFrequency.custom &&
              (intervalDays == null || intervalDays <= 0)
          ? 'Enter how many days between charges.'
          : null;
    });
    if (_nameError != null ||
        _amountError != null ||
        _bucketError != null ||
        _formError != null) {
      return;
    }

    final controller = ref.read(recurringControllerProvider.notifier);
    if (widget.isEditing) {
      await controller.updateDetails(id: widget.paymentId!, name: name, bucketId: bucketId!);
    } else {
      await controller.create(
        name: name,
        bucketId: bucketId!,
        frequency: _frequency,
        amountMinor: amount,
        startOn: _startOn,
        intervalDays: intervalDays,
      );
    }

    if (!mounted) return;
    if (ref.read(recurringControllerProvider).hasError) {
      setState(() => _formError = 'Could not save. Try again.');
      return;
    }
    context.pop();
  }

  Future<void> _addRateChangeDialog(RecurringPayment payment, String currency) async {
    final amountController = TextEditingController();
    var effectiveFrom = DateTime.now();
    setMoneyField(amountController, payment.currentAmountMinor, currency: currency);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Change amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MoneyField(controller: amountController, currency: currency, label: 'New amount'),
              const SizedBox(height: 12),
              Text('Effective from', style: Theme.of(dialogContext).textTheme.titleSmall),
              const SizedBox(height: 8),
              DateChip(
                date: effectiveFrom,
                semanticsLabel: 'Change effective date',
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                onChanged: (picked) => setDialogState(() => effectiveFrom = picked),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = moneyFromField(amountController);
                if (amount <= 0) return;
                Navigator.of(dialogContext).pop();
                await ref.read(recurringControllerProvider.notifier).addRatePeriod(
                      id: payment.id,
                      amountMinor: amount,
                      effectiveFrom: effectiveFrom,
                    );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stopDialog(RecurringPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop this payment?'),
        content: Text(
          'No new charges for "${payment.name}" will be generated after today. '
          'Past confirmed charges stay in your transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(recurringControllerProvider.notifier).stop(payment.id);
      if (mounted) context.pop();
    }
  }

  Future<void> _deleteOrStop(RecurringPayment payment) async {
    final hasExpenses =
        await ref.read(recurringControllerProvider.notifier).hasLinkedExpenses(payment.id);
    if (!mounted) return;
    if (hasExpenses) {
      // A payment with confirmed history can't be hard-deleted without
      // orphaning those expenses' occurrenceId — stopping it is the safe
      // equivalent.
      await _stopDialog(payment);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this payment?'),
        content: Text('"${payment.name}" has no confirmed charges yet, so this removes it completely.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(recurringControllerProvider.notifier).delete(payment.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyCodeProvider);
    final bucketsAsync = ref.watch(activeBucketsProvider);
    final isSaving = ref.watch(recurringControllerProvider).isLoading;

    Widget buildForm(RecurringPayment? existing) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            controller: _nameController,
            autofocus: !widget.isEditing,
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
          if (widget.isEditing) ...[
            const SizedBox(height: 4),
            Text(
              'To change the amount, use "Change amount" below instead — it '
              'keeps a history of what this cost before.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
                decoration: InputDecoration(labelText: 'Bucket', errorText: _bucketError),
                items: [
                  for (final bucket in buckets)
                    DropdownMenuItem(value: bucket.id, child: Text(bucket.name)),
                ],
                onChanged: (value) => setState(() => _bucketId = value),
              );
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RecurringFrequency>(
            initialValue: _frequency,
            // Frequency and start date only take effect at creation — an
            // existing payment's occurrence schedule is already fixed by its
            // startOn/frequency, and editing them here would silently
            // reshuffle history rather than just renaming/rebucketing.
            onChanged: widget.isEditing
                ? null
                : (value) => setState(() => _frequency = value ?? _frequency),
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: const [
              DropdownMenuItem(value: RecurringFrequency.daily, child: Text('Daily')),
              DropdownMenuItem(value: RecurringFrequency.weekly, child: Text('Weekly')),
              DropdownMenuItem(value: RecurringFrequency.biweekly, child: Text('Every 2 weeks')),
              DropdownMenuItem(value: RecurringFrequency.monthly, child: Text('Monthly')),
              DropdownMenuItem(value: RecurringFrequency.yearly, child: Text('Yearly')),
              DropdownMenuItem(value: RecurringFrequency.custom, child: Text('Custom')),
            ],
          ),
          if (_frequency == RecurringFrequency.custom && !widget.isEditing) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Days between charges', errorText: _formError),
            ),
          ],
          if (!widget.isEditing) ...[
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
          ],
          if (_formError != null && !(_frequency == RecurringFrequency.custom && !widget.isEditing)) ...[
            const SizedBox(height: 16),
            Text(
              _formError!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
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
                : Text(widget.isEditing ? 'Save' : 'Create'),
          ),
          if (widget.isEditing && existing != null) ...[
            const SizedBox(height: 32),
            Divider(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _addRateChangeDialog(existing, currency),
              icon: const Icon(Icons.trending_up),
              label: const Text('Change amount'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _stopDialog(existing),
              icon: const Icon(Icons.pause_circle_outlined),
              label: const Text('Stop this payment'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
              onPressed: () => _deleteOrStop(existing),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ],
      );
    }

    if (!widget.isEditing) {
      return Scaffold(
        appBar: AppBar(title: const Text('New recurring payment')),
        body: buildForm(null),
      );
    }

    final paymentsAsync = ref.watch(recurringPaymentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit recurring payment')),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load payment: $error')),
        data: (payments) {
          RecurringPayment? payment;
          for (final candidate in payments) {
            if (candidate.id == widget.paymentId) {
              payment = candidate;
              break;
            }
          }
          if (payment == null) {
            return const Center(child: Text('Recurring payment not found.'));
          }
          _prefill(payment, currency);
          return buildForm(payment);
        },
      ),
    );
  }
}
