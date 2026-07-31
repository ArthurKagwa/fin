import 'package:fintrack/core/app_lock/app_lock_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldBlock', () {
    test('blocks only when enabled and locked', () {
      expect(const AppLockState(enabled: true, locked: true).shouldBlock, isTrue);
      expect(const AppLockState(enabled: true, locked: false).shouldBlock, isFalse);
      expect(const AppLockState.off().shouldBlock, isFalse);
    });

    test('a stale locked flag cannot block while app lock is off', () {
      // The state that would strand a user behind a lock screen they can
      // no longer turn off.
      expect(const AppLockState(enabled: false, locked: true).shouldBlock, isFalse);
    });
  });

  group('relocked — backgrounding', () {
    test('re-arms the lock when enabled', () {
      final state = const AppLockState(enabled: true, locked: false).relocked();
      expect(state.locked, isTrue);
      expect(state.shouldBlock, isTrue);
    });

    test('is a no-op when app lock is off', () {
      final state = const AppLockState.off().relocked();
      expect(state.locked, isFalse);
      expect(state.enabled, isFalse);
    });

    test('is idempotent — backgrounding twice stays locked', () {
      final state = const AppLockState(enabled: true, locked: true).relocked().relocked();
      expect(state.shouldBlock, isTrue);
    });
  });

  group('unlocked — successful authentication', () {
    test('opens the lock but leaves app lock enabled', () {
      final state = const AppLockState(enabled: true, locked: true).unlocked();
      expect(state.locked, isFalse);
      expect(state.enabled, isTrue, reason: 'unlocking must not turn the feature off');
      expect(state.shouldBlock, isFalse);
    });
  });

  group('withEnabled — toggling the setting', () {
    test('turning on leaves the app open, not immediately locked', () {
      // The user just authenticated to enable it; demanding it again on the
      // spot would be pure theatre.
      final state = const AppLockState.off().withEnabled(true);
      expect(state.enabled, isTrue);
      expect(state.shouldBlock, isFalse);
    });

    test('turning off clears a locked flag rather than leaving it stale', () {
      final state = const AppLockState(enabled: true, locked: true).withEnabled(false);
      expect(state.enabled, isFalse);
      expect(state.locked, isFalse);
      expect(state.shouldBlock, isFalse);
    });

    test('a full enable → background → unlock → disable cycle ends unblocked', () {
      var state = const AppLockState.off();
      state = state.withEnabled(true);
      expect(state.shouldBlock, isFalse);

      state = state.relocked();
      expect(state.shouldBlock, isTrue);

      state = state.unlocked();
      expect(state.shouldBlock, isFalse);

      state = state.withEnabled(false);
      expect(state.enabled, isFalse);
      expect(state.shouldBlock, isFalse);
    });
  });
}
