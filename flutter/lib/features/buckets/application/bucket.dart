class Bucket {
  const Bucket({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.plannedMinor,
    this.goalMinor,
  });

  final String id;
  final String name;
  final int sortOrder;
  final int? plannedMinor;
  final int? goalMinor;

  Bucket copyWith({
    String? id,
    String? name,
    int? sortOrder,
    int? plannedMinor,
    int? goalMinor,
  }) {
    return Bucket(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      plannedMinor: plannedMinor ?? this.plannedMinor,
      goalMinor: goalMinor ?? this.goalMinor,
    );
  }
}
