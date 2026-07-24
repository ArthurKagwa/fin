enum IncomeKind { paycheque, other }

class Deduction {
  const Deduction({
    required this.id,
    required this.label,
    required this.amountMinor,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final int amountMinor;
  final int sortOrder;
}

class IncomeEvent {
  const IncomeEvent({
    required this.id,
    required this.kind,
    required this.amountMinor,
    required this.occurredOn,
    required this.source,
    this.grossMinor,
    this.note,
    this.deductions = const [],
  });

  final String id;
  final IncomeKind kind;
  final int amountMinor;
  final DateTime occurredOn;
  final String source;
  final int? grossMinor;
  final String? note;
  final List<Deduction> deductions;

  bool get isPaycheque => kind == IncomeKind.paycheque;

  int get deductionsTotalMinor =>
      deductions.fold(0, (sum, d) => sum + d.amountMinor);
}
