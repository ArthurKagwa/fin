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
