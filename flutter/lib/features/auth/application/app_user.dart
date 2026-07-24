class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final bool emailVerified;

  AppUser copyWith({
    String? id,
    String? email,
    bool? emailVerified,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          id == other.id &&
          email == other.email &&
          emailVerified == other.emailVerified;

  @override
  int get hashCode => Object.hash(id, email, emailVerified);
}
