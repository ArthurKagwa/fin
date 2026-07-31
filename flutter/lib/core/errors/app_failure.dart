sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  /// Screens interpolate errors directly (`'Could not load: $error'`), so the
  /// default `Instance of 'NetworkFailure'` would leak into user-facing copy.
  @override
  String toString() => message;
}

final class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

/// Rendering or sharing an exported document failed.
final class ExportFailure extends AppFailure {
  const ExportFailure(super.message);
}

/// A write was rejected because it would violate an invariant checked inside
/// a transaction — e.g. allocating more than is currently unallocated.
final class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message);
}

/// Firebase Auth requires a recent sign-in for this action (account
/// deletion) and the current session is too old. The caller should prompt
/// re-authentication and retry, not just show this as a dead-end error.
final class ReauthRequiredFailure extends AppFailure {
  const ReauthRequiredFailure(super.message);
}
