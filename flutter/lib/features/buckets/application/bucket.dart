class Bucket {
  const Bucket({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.plannedMinor,
    this.goalMinor,
    this.archivedAt,
    this.balanceMinor = 0,
  });

  final String id;
  final String name;
  final int sortOrder;
  final int? plannedMinor;
  final int? goalMinor;

  /// The envelope's running balance — allocations in, expenses out, carried
  /// over forever rather than reset monthly. This *is* the rollover FR-21
  /// asks for: no separate "carried over" figure to compute, because the
  /// balance never resets between months.
  final int balanceMinor;

  /// Set when the bucket was archived rather than hard-deleted — the case
  /// once it has any expenses, recurring payments, or allocations
  /// referencing it. Archived buckets stay out of pickers used to create new
  /// records but keep appearing anywhere historical reconciliation needs
  /// them (dashboard, plan-vs-actual, transactions list).
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  Bucket copyWith({
    String? id,
    String? name,
    int? sortOrder,
    int? plannedMinor,
    int? goalMinor,
    DateTime? archivedAt,
    int? balanceMinor,
  }) {
    return Bucket(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      plannedMinor: plannedMinor ?? this.plannedMinor,
      goalMinor: goalMinor ?? this.goalMinor,
      archivedAt: archivedAt ?? this.archivedAt,
      balanceMinor: balanceMinor ?? this.balanceMinor,
    );
  }
}
