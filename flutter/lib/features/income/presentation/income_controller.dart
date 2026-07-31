import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/income/data/income_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'income_controller.g.dart';

@riverpod
class IncomeController extends _$IncomeController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> addIncome({
    required IncomeKind kind,
    required int amountMinor,
    required DateTime occurredOn,
    required String source,
    int? grossMinor,
    String? note,
    List<({String label, int amountMinor})> deductions = const [],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(incomeRepositoryProvider).addIncomeEvent(
            kind: kind,
            amountMinor: amountMinor,
            occurredOn: occurredOn,
            source: source,
            grossMinor: grossMinor,
            note: note,
            deductions: deductions,
          ),
    );
  }

  Future<void> updateIncome(
    String id, {
    required IncomeKind kind,
    required int amountMinor,
    required DateTime occurredOn,
    required String source,
    int? grossMinor,
    String? note,
    List<({String label, int amountMinor})> deductions = const [],
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(incomeRepositoryProvider).updateIncomeEvent(
            id,
            kind: kind,
            amountMinor: amountMinor,
            occurredOn: occurredOn,
            source: source,
            grossMinor: grossMinor,
            note: note,
            deductions: deductions,
          ),
    );
  }

  Future<void> deleteIncome(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(incomeRepositoryProvider).deleteIncomeEvent(id),
    );
  }

  Future<void> restoreIncome(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(incomeRepositoryProvider).restoreIncomeEvent(id),
    );
  }
}
