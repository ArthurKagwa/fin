import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/core/widgets/date_chip.dart';
import 'package:fintrack/core/widgets/money_field.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/income/presentation/income_controller.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddIncomeSheet extends ConsumerStatefulWidget {
  const AddIncomeSheet({super.key, this.event});

  /// Passed directly by the caller, same as [AddExpenseSheet] — the income
  /// list already holds it, so there's no id-lookup route to resolve.
  final IncomeEvent? event;

  bool get isEditing => event != null;

  @override
  ConsumerState<AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _DeductionRow {
  _DeductionRow() : label = TextEditingController(), amount = TextEditingController();

  final TextEditingController label;
  final TextEditingController amount;
}

class _AddIncomeSheetState extends ConsumerState<AddIncomeSheet> {
  IncomeKind _kind = IncomeKind.other;
  final _sourceController = TextEditingController();
  final _amountController = TextEditingController();
  final _grossController = TextEditingController();
  DateTime _date = DateTime.now();
  final List<_DeductionRow> _deductions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event == null) return;
    final currency = ref.read(currencyCodeProvider);
    _kind = event.kind;
    _sourceController.text = event.source;
    _date = event.occurredOn;
    if (event.isPaycheque) {
      setMoneyField(_grossController, event.grossMinor, currency: currency);
      for (final deduction in event.deductions) {
        final row = _DeductionRow();
        row.label.text = deduction.label;
        setMoneyField(row.amount, deduction.amountMinor, currency: currency);
        _deductions.add(row);
      }
    } else {
      setMoneyField(_amountController, event.amountMinor, currency: currency);
    }
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _amountController.dispose();
    _grossController.dispose();
    for (final row in _deductions) {
      row.label.dispose();
      row.amount.dispose();
    }
    super.dispose();
  }

  int get _deductionsTotal =>
      _deductions.fold(0, (sum, row) => sum + moneyFromField(row.amount));

  Future<void> _save() async {
    final source = _sourceController.text.trim();
    if (source.isEmpty) {
      setState(() => _error = 'Enter a source');
      return;
    }

    final int amountMinor;
    final int? grossMinor;
    final List<({String label, int amountMinor})> deductions;

    if (_kind == IncomeKind.other) {
      final amount = moneyFromField(_amountController);
      if (amount <= 0) {
        setState(() => _error = 'Amount must be more than zero');
        return;
      }
      amountMinor = amount;
      grossMinor = null;
      deductions = const [];
    } else {
      final gross = moneyFromField(_grossController);
      if (gross <= 0) {
        setState(() => _error = 'Gross amount must be more than zero');
        return;
      }
      if (_deductionsTotal > gross) {
        setState(() => _error = 'Deductions can\'t exceed gross');
        return;
      }
      amountMinor = gross - _deductionsTotal;
      grossMinor = gross;
      deductions = [
        for (final row in _deductions)
          if (row.label.text.trim().isNotEmpty)
            (label: row.label.text.trim(), amountMinor: moneyFromField(row.amount)),
      ];
    }

    final controller = ref.read(incomeControllerProvider.notifier);
    if (widget.isEditing) {
      await controller.updateIncome(
        widget.event!.id,
        kind: _kind,
        amountMinor: amountMinor,
        occurredOn: _date,
        source: source,
        grossMinor: grossMinor,
        deductions: deductions,
      );
    } else {
      await controller.addIncome(
        kind: _kind,
        amountMinor: amountMinor,
        occurredOn: _date,
        source: source,
        grossMinor: grossMinor,
        deductions: deductions,
      );
    }

    if (!mounted) return;
    final error = ref.read(incomeControllerProvider).hasError;
    if (error) {
      setState(() => _error = 'Could not save. Try again.');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyCodeProvider);
    final isLoading = ref.watch(incomeControllerProvider).isLoading;
    final gross = moneyFromField(_grossController);
    final takeHome = gross - _deductionsTotal;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
            Text(
              widget.isEditing ? 'Edit money in' : 'Add money in',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            SegmentedButton<IncomeKind>(
              segments: const [
                ButtonSegment(value: IncomeKind.other, label: Text('Other')),
                ButtonSegment(value: IncomeKind.paycheque, label: Text('Paycheque')),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) => setState(() => _kind = selection.first),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _sourceController,
              decoration: const InputDecoration(labelText: 'Source'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: DateChip(
                date: _date,
                onChanged: (picked) => setState(() => _date = picked),
              ),
            ),
            const SizedBox(height: 20),
            if (_kind == IncomeKind.other)
              MoneyField(
                controller: _amountController,
                currency: currency,
                label: 'Amount',
                onChanged: (_) => setState(() => _error = null),
              )
            else ...[
              MoneyField(
                controller: _grossController,
                currency: currency,
                label: 'Gross amount',
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 16),
              Text('Deductions', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final row in _deductions) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: row.label,
                        decoration: const InputDecoration(labelText: 'Label'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MoneyField(
                        controller: row.amount,
                        currency: currency,
                        label: 'Amount',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _deductions.remove(row)),
                    ),
                  ],
                ),
              ],
              TextButton.icon(
                onPressed: () => setState(() => _deductions.add(_DeductionRow())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add deduction'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Take-home', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    formatMoney(takeHome < 0 ? 0 : takeHome, currency: currency),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.secondary,
                        ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error)),
            ],
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
