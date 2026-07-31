class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.emailVerified,
    this.createdAt,
  });

  final String id;
  final String email;
  final bool emailVerified;

  /// When the account was created. Nullable because Firebase only populates
  /// user metadata for a real signed-in session — it is absent in tests and
  /// on some restored sessions, so the UI must degrade rather than assume.
  final DateTime? createdAt;

  AppUser copyWith({
    String? id,
    String? email,
    bool? emailVerified,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          id == other.id &&
          email == other.email &&
          emailVerified == other.emailVerified &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, email, emailVerified, createdAt);
}
