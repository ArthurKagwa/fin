sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
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
