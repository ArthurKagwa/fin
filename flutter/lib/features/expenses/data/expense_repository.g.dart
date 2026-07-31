// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(expenseRepository)
final expenseRepositoryProvider = ExpenseRepositoryProvider._();

final class ExpenseRepositoryProvider
    extends
        $FunctionalProvider<
          ExpenseRepository,
          ExpenseRepository,
          ExpenseRepository
        >
    with $Provider<ExpenseRepository> {
  ExpenseRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expenseRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expenseRepositoryHash();

  @$internal
  @override
  $ProviderElement<ExpenseRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExpenseRepository create(Ref ref) {
    return expenseRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExpenseRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExpenseRepository>(value),
    );
  }
}

String _$expenseRepositoryHash() => r'2ccd938e3c63e68e5613afefcdc586265cccc5d8';

@ProviderFor(expensesForMonth)
final expensesForMonthProvider = ExpensesForMonthFamily._();

final class ExpensesForMonthProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Expense>>,
          List<Expense>,
          Stream<List<Expense>>
        >
    with $FutureModifier<List<Expense>>, $StreamProvider<List<Expense>> {
  ExpensesForMonthProvider._({
    required ExpensesForMonthFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'expensesForMonthProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expensesForMonthHash();

  @override
  String toString() {
    return r'expensesForMonthProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Expense>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Expense>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return expensesForMonth(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpensesForMonthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expensesForMonthHash() => r'75c6ac0ade120def31bba8105b5907029ff5d2a7';

final class ExpensesForMonthFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Expense>>, DateTime> {
  ExpensesForMonthFamily._()
    : super(
        retry: null,
        name: r'expensesForMonthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExpensesForMonthProvider call(DateTime month) =>
      ExpensesForMonthProvider._(argument: month, from: this);

  @override
  String toString() => r'expensesForMonthProvider';
}

/// Only ever renders the last 5 rows on the dashboard, but reads the whole
/// history without a cap — this bounds it well above what's shown so the
/// query cost stops growing linearly with account age.

@ProviderFor(recentExpenses)
final recentExpensesProvider = RecentExpensesProvider._();

/// Only ever renders the last 5 rows on the dashboard, but reads the whole
/// history without a cap — this bounds it well above what's shown so the
/// query cost stops growing linearly with account age.

final class RecentExpensesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Expense>>,
          List<Expense>,
          Stream<List<Expense>>
        >
    with $FutureModifier<List<Expense>>, $StreamProvider<List<Expense>> {
  /// Only ever renders the last 5 rows on the dashboard, but reads the whole
  /// history without a cap — this bounds it well above what's shown so the
  /// query cost stops growing linearly with account age.
  RecentExpensesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentExpensesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentExpensesHash();

  @$internal
  @override
  $StreamProviderElement<List<Expense>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Expense>> create(Ref ref) {
    return recentExpenses(ref);
  }
}

String _$recentExpensesHash() => r'30e9b8d42c008ba32826e6cca1ccd5edb4405566';
