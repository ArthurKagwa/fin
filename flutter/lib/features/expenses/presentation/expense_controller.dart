import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expense_controller.g.dart';

@riverpod
class ExpenseController extends _$ExpenseController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> addExpense({
    required String bucketId,
    required int amountMinor,
    required DateTime occurredOn,
    String? payee,
    String? note,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(expenseRepositoryProvider).addExpense(
            bucketId: bucketId,
            amountMinor: amountMinor,
            occurredOn: occurredOn,
            payee: payee,
            note: note,
          ),
    );
  }
}
