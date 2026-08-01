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

/// The budget itself: what you expect to come in, and where you are sending it.
///
/// Hosted twice — as the Plan tab for the current month, and behind
/// `/plan/edit` for whichever month the report is showing — so the entry rules
/// and the distribution arithmetic live here rather than being written twice.
///
/// [header] and [footer] are spliced into the same scroll view as the fields.
/// A screen that wrapped this in a `Column` would give the form an unbounded
/// height and lose the single scroll the month's budget wants to be.
class PlanEditorForm extends ConsumerStatefulWidget {
  const PlanEditorForm({
    super.key,
    required this.month,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 32),
    this.header = const <Widget>[],
    this.footer = const <Widget>[],
    this.onSaved,
  });

  final DateTime month;
  final EdgeInsetsGeometry padding;
  final List<Widget> header;
  final List<Widget> footer;

  /// Called after a successful save. A host that navigated here pops; the tab
  /// leaves the user where they are and lets the form confirm with a snackbar.
  final VoidCallback? onSaved;

  @override
  ConsumerState<PlanEditorForm> createState() => _PlanEditorFormState();
}

class _PlanEditorFormState extends ConsumerState<PlanEditorForm> {
  final _incomeRows = <_IncomeRowState>[];

  /// Rows and fields the user removed, or that belonged to a month we have
  /// since moved off. Their controllers are still attached to fields being
  /// torn down this frame, so they're disposed with the form rather than at
  /// the moment of removal.
  final _removedRows = <_IncomeRowState>[];
  final _removedControllers = <TextEditingController>[];
  final _bucketControllers = <String, TextEditingController>{};
  bool _prefilled = false;
  String? _error;

  @override
  void didUpdateWidget(covariant PlanEditorForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month) {
      _removedRows.addAll(_incomeRows);
      _incomeRows.clear();
      _removedControllers.addAll(_bucketControllers.values);
      _bucketControllers.clear();
      _prefilled = false;
    }
  }

  @override
  void dispose() {
    for (final row in [..._incomeRows, ..._removedRows]) {
      row.dispose();
    }
    for (final controller in [
      ..._bucketControllers.values,
      ..._removedControllers,
    ]) {
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

  /// Everything the user expects to receive this month.
  int get _expectedIncomeMinor => _incomeRows.fold<int>(
        0,
        (sum, row) => sum + moneyFromField(row.amount),
      );

  /// Everything they have given a job to.
  int get _distributedMinor => _bucketControllers.values.fold<int>(
        0,
        (sum, controller) => sum + moneyFromField(controller),
      );

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
    final messenger = ScaffoldMessenger.of(context);
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
    // Distributing more than you expect to earn is allowed — same rule as
    // overspending a bucket: warn, never block. It is said once here, after
    // the plan is safely stored.
    final over = _distributedMinor - _expectedIncomeMinor;
    final currency = ref.read(currencyCodeProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          over > 0
              ? 'Plan saved — ${formatMoney(over, currency: currency)} more '
                  'distributed than you expect to earn'
              : 'Plan saved',
        ),
      ),
    );
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(monthlyPlanProvider(widget.month));
    final bucketsAsync = ref.watch(activeBucketsProvider);
    final currency = ref.watch(currencyCodeProvider);
    final isSaving = ref.watch(planControllerProvider).isLoading;

    return planAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load the plan: $error'),
        ),
      ),
      data: (plan) => bucketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load buckets: $error'),
          ),
        ),
        data: (buckets) {
          _prefill(plan, buckets, currency);
          return _buildForm(buckets, currency, isSaving);
        },
      ),
    );
  }

  Widget _buildForm(List<Bucket> buckets, String currency, bool isSaving) {
    final theme = Theme.of(context);

    return ListView(
      padding: widget.padding,
      children: [
        ...widget.header,
        Text('Money you expect', style: theme.textTheme.titleLarge),
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
            onChanged: () => setState(() {}),
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
        const SizedBox(height: 20),
        _DistributionSummary(
          expectedMinor: _expectedIncomeMinor,
          distributedMinor: _distributedMinor,
          currency: currency,
        ),
        const SizedBox(height: 24),
        Text('Give it a job', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Decide what each bucket gets before the month spends it for you.',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
              onChanged: (_) => setState(() {}),
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
          onPressed: isSaving ? null : () => _save(widget.month),
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save plan'),
        ),
        ...widget.footer,
      ],
    );
  }
}

/// The one number that says whether the budget is finished: expected income
/// less everything already given a job.
class _DistributionSummary extends StatelessWidget {
  const _DistributionSummary({
    required this.expectedMinor,
    required this.distributedMinor,
    required this.currency,
  });

  final int expectedMinor;
  final int distributedMinor;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final leftMinor = expectedMinor - distributedMinor;
    final isOver = leftMinor < 0;
    final isDone = leftMinor == 0 && expectedMinor > 0;

    final label = isOver
        ? 'Over-committed by'
        : isDone
            ? 'Every unit has a job'
            : 'Left to distribute';
    final amountColour = isOver
        ? colorScheme.error
        : isDone
            ? colorScheme.secondary
            : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  formatMoney(leftMinor.abs(), currency: currency),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: amountColour,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: expectedMinor <= 0
                    ? 0
                    : (distributedMinor / expectedMinor).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: isOver ? colorScheme.error : colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              expectedMinor <= 0
                  ? 'Add what you expect to earn, then split it across your buckets.'
                  : '${formatMoney(distributedMinor, currency: currency)} of '
                      '${formatMoney(expectedMinor, currency: currency)} distributed',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
    required this.onChanged,
    this.onRemove,
  });

  final _IncomeRowState row;
  final String currency;
  final VoidCallback onChanged;
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
            onChanged: (_) => onChanged(),
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
