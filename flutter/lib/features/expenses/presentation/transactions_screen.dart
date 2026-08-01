import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:fintrack/features/expenses/presentation/add_expense_sheet.dart';
import 'package:fintrack/features/expenses/presentation/expense_controller.dart';
import 'package:fintrack/features/planning/application/monthly_plan.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/features/recurring/presentation/recurring_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which half of the record the screen opens on.
enum TransactionsTab { expenses, recurring }

/// The record of money out: what has already been spent, and what is set to
/// repeat.
///
/// Recurring used to be its own bottom-nav destination, which split one
/// question — "what has left my account and what is about to?" — across two
/// places. Both are transactions; only their tense differs, so they are two
/// tabs of one screen.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({
    super.key,
    this.initialTab = TransactionsTab.expenses,
  });

  final TransactionsTab initialTab;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: TransactionsTab.values.length,
    initialIndex: widget.initialTab.index,
    vsync: this,
  );
  late DateTime _month = normaliseMonth(DateTime.now());
  final _searchController = TextEditingController();
  String? _filterBucketId;

  bool get _canGoForward => _month.isBefore(normaliseMonth(DateTime.now()));

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Expense> _applyFilters(List<Expense> expenses) {
    final query = _searchController.text.trim().toLowerCase();
    return expenses.where((expense) {
      if (_filterBucketId != null && expense.bucketId != _filterBucketId) return false;
      if (query.isEmpty) return true;
      final haystack = '${expense.payee ?? ''} ${expense.note ?? ''}'.toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Recurring'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExpenses(context),
          const RecurringView(),
        ],
      ),
    );
  }

  Widget _buildExpenses(BuildContext context) {
    final expensesAsync = ref.watch(expensesForMonthProvider(_month));
    final bucketsAsync = ref.watch(activeBucketsProvider);
    final currency = ref.watch(currencyCodeProvider);

    return Column(
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search payee or note',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(_searchController.clear),
                    ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        bucketsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (buckets) {
            if (buckets.length < 2) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _filterBucketId == null,
                        onSelected: (_) => setState(() => _filterBucketId = null),
                      ),
                    ),
                    for (final bucket in buckets)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(bucket.name),
                          selected: _filterBucketId == bucket.id,
                          onSelected: (_) => setState(() => _filterBucketId = bucket.id),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
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
            data: (allExpenses) {
              final expenses = _applyFilters(allExpenses);
              if (expenses.isEmpty) {
                return allExpenses.isEmpty
                    ? _EmptyMonth(month: _month)
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Nothing matches that search or filter.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      );
              }
              final names = {
                for (final bucket in bucketsAsync.asData?.value ?? const <Bucket>[])
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
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => AddExpenseSheet(expense: expense),
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
