import 'package:fintrack/features/income/application/income_event.dart';

abstract class IncomeRepository {
  Stream<List<IncomeEvent>> watchIncomeEvents();
  Future<IncomeEvent> addIncomeEvent({
    required IncomeKind kind,
    required int amountMinor,
    required DateTime occurredOn,
    required String source,
    int? grossMinor,
    String? note,
    List<({String label, int amountMinor})> deductions = const [],
  });
}

class FirestoreIncomeRepository implements IncomeRepository {
  @override
  Stream<List<IncomeEvent>> watchIncomeEvents() => throw UnimplementedError();

  @override
  Future<IncomeEvent> addIncomeEvent({
    required IncomeKind kind,
    required int amountMinor,
    required DateTime occurredOn,
    required String source,
    int? grossMinor,
    String? note,
    List<({String label, int amountMinor})> deductions = const [],
  }) =>
      throw UnimplementedError();
}
