import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:fintrack/features/expenses/presentation/expense_controller.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every expense in a month, grouped by day, with swipe-to-delete.
///
/// Before this existed, expenses were only ever visible as the last five rows
/// on the dashboard — so anything older than a few entries could not be
/// reviewed, corrected or even seen.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late DateTime _month = normaliseMonth(DateTime.now());

  bool get _canGoForward => _month.isBefore(normaliseMonth(DateTime.now()));

  Future<void> _delete(Expense expense, String bucketName) async {
    final messenger = ScaffoldMessenger.of(context);
    final currency = ref.read(currencyCodeProvider);
    await ref.read(expenseControllerProvider.notifier).deleteExpense(expense.id);
    if (!mounted) return;

    if (ref.read(expenseControllerProvider).hasError) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete. Try again.')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${formatMoney(expense.amountMinor, currency: currency)} '
          'in $bucketName deleted',
        ),
        duration: const Duration(seconds: 6),
        // Deletes are soft, so undo is a field flip rather than a re-insert —
        // which is why a swipe can act immediately instead of interrupting
        // with a confirmation dialog.
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref
              .read(expenseControllerProvider.notifier)
              .restoreExpense(expense.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesForMonthProvider(_month));
    final bucketsAsync = ref.watch(activeBucketsProvider);
    final currency = ref.watch(currencyCodeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous month',
                ),
                Expanded(
                  child: Text(
                    formatMonth(_month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _canGoForward
                      ? () => setState(
                            () => _month =
                                DateTime(_month.year, _month.month + 1),
                          )
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next month',
                ),
              ],
            ),
          ),
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load transactions: $error'),
                ),
              ),
              data: (expenses) {
                if (expenses.isEmpty) return _EmptyMonth(month: _month);
                final names = {
                  for (final bucket in bucketsAsync.asData?.value ?? const [])
                    bucket.id: bucket.name,
                };
                return _TransactionList(
                  expenses: expenses,
                  bucketNames: names,
                  currency: currency,
                  onDelete: _delete,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.expenses,
    required this.bucketNames,
    required this.currency,
    required this.onDelete,
  });

  final List<Expense> expenses;
  final Map<String, String> bucketNames;
  final String currency;
  final void Function(Expense expense, String bucketName) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byDay = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      final day = DateTime(
        expense.occurredOn.year,
        expense.occurredOn.month,
        expense.occurredOn.day,
      );
      byDay.putIfAbsent(day, () => []).add(expense);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final monthTotal =
        expenses.fold<int>(0, (sum, e) => sum + e.amountMinor);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${expenses.length} '
                  '${expenses.length == 1 ? 'entry' : 'entries'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatMoney(monthTotal, currency: currency),
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  relativeDate(day),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  formatMoney(
                    byDay[day]!.fold<int>(0, (sum, e) => sum + e.amountMinor),
                    currency: currency,
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < byDay[day]!.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  _SwipeableExpense(
                    expense: byDay[day]![i],
                    bucketName: bucketNames[byDay[day]![i].bucketId] ??
                        'Deleted bucket',
                    currency: currency,
                    onDelete: onDelete,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _SwipeableExpense extends StatelessWidget {
  const _SwipeableExpense({
    required this.expense,
    required this.bucketName,
    required this.currency,
    required this.onDelete,
  });

  final Expense expense;
  final String bucketName;
  final String currency;
  final void Function(Expense expense, String bucketName) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(expense, bucketName),
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.surfaceContainerHigh,
          foregroundColor: colorScheme.onSurfaceVariant,
          child: const Icon(Icons.receipt_long_outlined, size: 18),
        ),
        title: Text(expense.payee ?? bucketName),
        subtitle: Text(bucketName),
        trailing: Text(
          formatMoney(expense.amountMinor, currency: currency),
          style: theme.textTheme.titleSmall,
        ),
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nothing logged', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'No expenses recorded in ${formatMonth(month)}.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
