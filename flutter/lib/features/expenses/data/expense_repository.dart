import 'package:fintrack/features/expenses/application/expense.dart';

abstract class ExpenseRepository {
  Future<Expense> addExpense({
    required String bucketId,
    required int amountMinor,
    required DateTime occurredOn,
    String? payee,
    String? note,
  });

  Future<void> deleteExpense(String id);
  Stream<List<Expense>> watchExpenses({DateTime? month});
}

class FirestoreExpenseRepository implements ExpenseRepository {
  @override
  Future<Expense> addExpense({
    required String bucketId,
    required int amountMinor,
    required DateTime occurredOn,
    String? payee,
    String? note,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteExpense(String id) => throw UnimplementedError();

  @override
  Stream<List<Expense>> watchExpenses({DateTime? month}) =>
      throw UnimplementedError();
}
