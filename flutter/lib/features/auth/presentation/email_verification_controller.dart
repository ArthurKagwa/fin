import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'email_verification_controller.g.dart';

@riverpod
class EmailVerificationController extends _$EmailVerificationController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> resend() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendEmailVerification(),
    );
  }

  Future<void> checkVerified() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).reloadCurrentUser(),
    );
  }
}
