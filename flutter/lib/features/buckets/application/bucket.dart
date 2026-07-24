class Bucket {
  const Bucket({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.plannedMinor,
    this.goalMinor,
    this.archivedAt,
  });

  final String id;
  final String name;
  final int sortOrder;
  final int? plannedMinor;
  final int? goalMinor;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  Bucket copyWith({
    String? id,
    String? name,
    int? sortOrder,
    int? plannedMinor,
    int? goalMinor,
    DateTime? archivedAt,
  }) {
    return Bucket(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      plannedMinor: plannedMinor ?? this.plannedMinor,
      goalMinor: goalMinor ?? this.goalMinor,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}
