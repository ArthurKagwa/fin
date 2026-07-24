class Expense {
  const Expense({
    required this.id,
    required this.bucketId,
    required this.amountMinor,
    required this.occurredOn,
    this.payee,
    this.note,
    this.occurrenceId,
    this.deletedAt,
  });

  final String id;
  final String bucketId;
  final int amountMinor;
  final DateTime occurredOn;
  final String? payee;
  final String? note;
  final String? occurrenceId;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}
