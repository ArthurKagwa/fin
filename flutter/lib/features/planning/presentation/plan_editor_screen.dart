import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/core/widgets/money_field.dart';
import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/planning/data/plan_repository.dart';
import 'package:fintrack/features/planning/presentation/plan_controller.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Edits the plan for whichever month the report is showing.
///
/// Scoped to [selectedPlanMonthProvider] rather than a path parameter: the
/// month is already app state, and saving a plan against a month the user
/// isn't looking at is a mistake waiting to happen.
class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  final _incomeRows = <_IncomeRowState>[];

  /// Rows the user removed. Their controllers are still attached to fields
  /// being torn down this frame, so they're disposed with the screen rather
  /// than at the moment of removal.
  final _removedRows = <_IncomeRowState>[];
  final _bucketControllers = <String, TextEditingController>{};
  bool _prefilled = false;
  String? _error;

  @override
  void dispose() {
    for (final row in [..._incomeRows, ..._removedRows]) {
      row.dispose();
    }
    for (final controller in _bucketControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _prefill(MonthlyPlan plan, List<Bucket> buckets, String currency) {
    if (_prefilled) return;
    _prefilled = true;
    for (final income in plan.expectedIncomes) {
      _incomeRows.add(_IncomeRowState.from(income, currency));
    }
    if (_incomeRows.isEmpty) _incomeRows.add(_IncomeRowState.empty());
    for (final bucket in buckets) {
      final controller = TextEditingController();
      setMoneyField(controller, plan.plannedForBucket(bucket.id), currency: currency);
      _bucketControllers[bucket.id] = controller;
    }
  }

  Future<void> _save(DateTime month) async {
    final expectedIncomes = <ExpectedIncome>[];
    for (var i = 0; i < _incomeRows.length; i++) {
      final row = _incomeRows[i];
      final label = row.label.text.trim();
      final isBlank = moneyFieldIsEmpty(row.amount);
      final amount = moneyFromField(row.amount);
      // A half-filled row is a typo, not an intention — dropping it silently
      // would lose money from the plan without telling anyone.
      if (label.isEmpty && isBlank) continue;
      if (label.isEmpty || isBlank || amount <= 0) {
        setState(() {
          _error = label.isEmpty
              ? 'Name the income source on row ${i + 1}.'
              : 'Enter an amount for "$label".';
        });
        return;
      }
      expectedIncomes.add(
        ExpectedIncome(
          id: row.id,
          label: label,
          amountMinor: amount,
          sortOrder: i,
        ),
      );
    }

    final bucketPlans = <String, int>{};
    for (final entry in _bucketControllers.entries) {
      if (moneyFieldIsEmpty(entry.value)) continue;
      final amount = moneyFromField(entry.value);
      if (amount > 0) bucketPlans[entry.key] = amount;
    }

    setState(() => _error = null);
    await ref.read(planControllerProvider.notifier).save(
          month: month,
          expectedIncomes: expectedIncomes,
          bucketPlans: bucketPlans,
        );

    if (!mounted) return;
    if (ref.read(planControllerProvider).hasError) {
      setState(() => _error = 'Could not save your plan. Try again.');
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedPlanMonthProvider);
    final planAsync = ref.watch(monthlyPlanProvider(month));
    final bucketsAsync = ref.watch(activeBucketsProvider);
    final currency = ref.watch(currencyCodeProvider);
    final isSaving = ref.watch(planControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text('Plan for ${formatMonth(month)}')),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load the plan: $error')),
        data: (plan) => bucketsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Could not load buckets: $error')),
          data: (buckets) {
            _prefill(plan, buckets, currency);
            return _buildForm(month, buckets, currency, isSaving);
          },
        ),
      ),
    );
  }

  Widget _buildForm(
    DateTime month,
    List<Bucket> buckets,
    String currency,
    bool isSaving,
  ) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('Expected income', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Name each source the way you log it, so arrivals match up.',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _incomeRows.length; i++) ...[
          _IncomeSourceFields(
            row: _incomeRows[i],
            currency: currency,
            onRemove: _incomeRows.length == 1
                ? null
                : () => setState(
                      () => _removedRows.add(_incomeRows.removeAt(i)),
                    ),
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _incomeRows.add(_IncomeRowState.empty())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add source'),
          ),
        ),
        const SizedBox(height: 28),
        Text('Planned spend', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (buckets.isEmpty)
          Text(
            'No buckets yet — create one first.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final bucket in buckets) ...[
            MoneyField(
              // `_prefill` runs once, so a bucket created on another device
              // while this screen is open would have no controller. Creating
              // it lazily beats a null assertion crash.
              controller: _bucketControllers.putIfAbsent(
                bucket.id,
                TextEditingController.new,
              ),
              currency: currency,
              label: bucket.name,
            ),
            const SizedBox(height: 12),
          ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: isSaving ? null : () => _save(month),
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save plan'),
        ),
      ],
    );
  }
}

class _IncomeRowState {
  _IncomeRowState({required this.id, required this.label, required this.amount});

  factory _IncomeRowState.from(ExpectedIncome income, String currency) {
    final amount = TextEditingController();
    setMoneyField(amount, income.amountMinor, currency: currency);
    return _IncomeRowState(
      id: income.id,
      label: TextEditingController(text: income.label),
      amount: amount,
    );
  }

  factory _IncomeRowState.empty() => _IncomeRowState(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        label: TextEditingController(),
        amount: TextEditingController(),
      );

  final String id;
  final TextEditingController label;
  final TextEditingController amount;

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

class _IncomeSourceFields extends StatelessWidget {
  const _IncomeSourceFields({
    required this.row,
    required this.currency,
    this.onRemove,
  });

  final _IncomeRowState row;
  final String currency;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: row.label,
            decoration: const InputDecoration(labelText: 'Source'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: MoneyField(
            controller: row.amount,
            currency: currency,
            label: 'Amount',
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close),
          tooltip: 'Remove source',
        ),
      ],
    );
  }
}
