import 'package:fintrack/core/app_lock/app_lock_service.dart';
import 'package:fintrack/core/app_lock/app_lock_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_lock_controller.g.dart';

/// Raised by [AppLockController.enable] when the device has no screen lock
/// at all — enabling app lock there would shut the user out permanently.
class AppLockUnsupported implements Exception {
  const AppLockUnsupported();

  @override
  String toString() => 'Set up a screen lock on your device first.';
}

@Riverpod(keepAlive: true)
class AppLockController extends _$AppLockController {
  @override
  Future<AppLockState> build() async {
    final enabled = await ref.read(appLockServiceProvider).isEnabled();
    // Locked whenever enabled: a cold start should demand the same proof as
    // resuming from the background.
    return AppLockState(enabled: enabled, locked: enabled);
  }

  Future<void> enable() async {
    final service = ref.read(appLockServiceProvider);
    if (!await service.isSupported()) throw const AppLockUnsupported();

    // Prove the prompt actually works for this user before making it the
    // thing standing between them and their data.
    if (!await service.authenticate('Confirm it\'s you to turn on app lock')) {
      return;
    }
    await service.setEnabled(true);
    state = AsyncData((state.value ?? const AppLockState.off()).withEnabled(true));
  }

  /// Turning protection off demands the same proof as using it — otherwise
  /// anyone holding the unlocked phone could just switch it off.
  Future<void> disable() async {
    final service = ref.read(appLockServiceProvider);
    if (!await service.authenticate('Confirm it\'s you to turn off app lock')) {
      return;
    }
    await service.setEnabled(false);
    state = AsyncData((state.value ?? const AppLockState.off()).withEnabled(false));
  }

  /// Returns whether the unlock succeeded so the lock screen can offer a
  /// retry without unpacking [AsyncValue].
  Future<bool> unlock() async {
    final service = ref.read(appLockServiceProvider);
    final ok = await service.authenticate('Unlock FinTrack');
    if (ok) {
      state = AsyncData((state.value ?? const AppLockState.off()).unlocked());
    }
    return ok;
  }

  /// Re-arms the lock on backgrounding. Synchronous and a no-op when app
  /// lock is off, so the lifecycle observer can call it unconditionally.
  void relock() {
    final current = state.value;
    if (current == null || !current.enabled) return;
    state = AsyncData(current.relocked());
  }
}
