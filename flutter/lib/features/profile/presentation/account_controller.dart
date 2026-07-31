import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_controller.g.dart';

@riverpod
class AccountController extends _$AccountController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// May leave [state] holding a `ReauthRequiredFailure` — the screen checks
  /// for that specifically and prompts re-authentication before calling this
  /// again, rather than treating it as a dead-end error like everything else.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).deleteAccount());
  }

  Future<bool> reauthenticateWithPassword(String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).reauthenticateWithPassword(password),
    );
    return !state.hasError;
  }

  Future<bool> reauthenticateWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).reauthenticateWithGoogle(),
    );
    return !state.hasError;
  }
}
