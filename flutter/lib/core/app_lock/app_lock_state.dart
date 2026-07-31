/// Whether app lock is turned on, and whether it's currently holding the
/// app shut.
///
/// Pure — no plugin, no storage — so the transition rules below are
/// unit-testable without a device that can actually prompt for a
/// fingerprint.
class AppLockState {
  const AppLockState({required this.enabled, required this.locked});

  /// App lock is off entirely.
  const AppLockState.off() : enabled = false, locked = false;

  final bool enabled;

  /// Whether the lock screen should be showing right now. Meaningless when
  /// [enabled] is false — [shouldBlock] is what callers should read.
  final bool locked;

  /// The single question the router asks: hide everything behind the lock
  /// screen, or not?
  bool get shouldBlock => enabled && locked;

  /// Backgrounding the app re-arms the lock. A no-op when app lock is off,
  /// so the lifecycle observer can call this unconditionally.
  AppLockState relocked() => enabled ? const AppLockState(enabled: true, locked: true) : this;

  /// A successful authenticate() opens it.
  AppLockState unlocked() => AppLockState(enabled: enabled, locked: false);

  /// Turning app lock on leaves it open — the user just proved who they are
  /// to enable it, so immediately demanding it again would be theatre.
  /// Turning it off clears the locked flag too, so a stale `locked: true`
  /// can't strand the user behind a lock screen that's no longer enabled.
  AppLockState withEnabled(bool value) => AppLockState(enabled: value, locked: false);
}
