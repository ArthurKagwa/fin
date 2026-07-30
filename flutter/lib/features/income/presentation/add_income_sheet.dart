import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/income/presentation/income_controller.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddIncomeSheet extends ConsumerStatefulWidget {
  const AddIncomeSheet({super.key});

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

  int get _deductionsTotal => _deductions.fold(
        0,
        (sum, row) => sum + (int.tryParse(row.amount.text.replaceAll(',', '')) ?? 0),
      );

  Future<void> _save() async {
    final source = _sourceController.text.trim();
    if (source.isEmpty) {
      setState(() => _error = 'Enter a source');
      return;
    }

    if (_kind == IncomeKind.other) {
      final amount = int.tryParse(_amountController.text.replaceAll(',', ''));
      if (amount == null || amount <= 0) {
        setState(() => _error = 'Amount must be more than zero');
        return;
      }
      await ref.read(incomeControllerProvider.notifier).addIncome(
            kind: IncomeKind.other,
            amountMinor: amount,
            occurredOn: _date,
            source: source,
          );
    } else {
      final gross = int.tryParse(_grossController.text.replaceAll(',', ''));
      if (gross == null || gross <= 0) {
        setState(() => _error = 'Gross amount must be more than zero');
        return;
      }
      if (_deductionsTotal > gross) {
        setState(() => _error = 'Deductions can\'t exceed gross');
        return;
      }
      await ref.read(incomeControllerProvider.notifier).addIncome(
            kind: IncomeKind.paycheque,
            amountMinor: gross - _deductionsTotal,
            grossMinor: gross,
            occurredOn: _date,
            source: source,
            deductions: [
              for (final row in _deductions)
                if (row.label.text.trim().isNotEmpty)
                  (
                    label: row.label.text.trim(),
                    amountMinor: int.tryParse(row.amount.text.replaceAll(',', '')) ?? 0,
                  ),
            ],
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
    final gross = int.tryParse(_grossController.text.replaceAll(',', '')) ?? 0;
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
            Text('Add money in', style: Theme.of(context).textTheme.headlineMedium),
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
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(relativeDate(_date), style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_kind == IncomeKind.other)
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
                onChanged: (_) => setState(() {}),
              )
            else ...[
              TextField(
                controller: _grossController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Gross amount'),
                onChanged: (_) => setState(() {}),
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
                      child: TextField(
                        controller: row.amount,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Amount'),
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
                    formatMoney(takeHome < 0 ? 0 : takeHome, symbol: currency),
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
