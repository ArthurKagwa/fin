import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expense_controller.g.dart';

@riverpod
class ExpenseController extends _$ExpenseController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Returns the created expense so the caller can offer Undo, or null if the
  /// write failed — the error is in [state] either way.
  Future<Expense?> addExpense({
    required String bucketId,
    required int amountMinor,
    required DateTime occurredOn,
    String? payee,
    String? note,
  }) async {
    state = const AsyncLoading();
    Expense? created;
    state = await AsyncValue.guard(() async {
      created = await ref.read(expenseRepositoryProvider).addExpense(
            bucketId: bucketId,
            amountMinor: amountMinor,
            occurredOn: occurredOn,
            payee: payee,
            note: note,
          );
    });
    return state.hasError ? null : created;
  }

  Future<void> updateExpense(
    String id, {
    required String bucketId,
    required int amountMinor,
    required DateTime occurredOn,
    String? payee,
    String? note,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(expenseRepositoryProvider).updateExpense(
            id,
            bucketId: bucketId,
            amountMinor: amountMinor,
            occurredOn: occurredOn,
            payee: payee,
            note: note,
          ),
    );
  }

  Future<void> deleteExpense(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(expenseRepositoryProvider).deleteExpense(id),
    );
  }

  Future<void> restoreExpense(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(expenseRepositoryProvider).restoreExpense(id),
    );
  }
}
