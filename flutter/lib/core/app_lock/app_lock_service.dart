import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'app_lock_service.g.dart';

const _enabledKey = 'app_lock_enabled';

/// Wraps `local_auth` and the one local preference this app keeps.
///
/// App lock delegates entirely to whatever the device already uses —
/// Face ID, fingerprint, or the device PIN/pattern/passcode — rather than
/// storing a FinTrack-specific PIN. Nothing secret is persisted here, so
/// `shared_preferences` (not secure storage) is the right home for the
/// on/off flag: knowing that app lock is enabled tells an attacker nothing
/// they can use.
class AppLockService {
  final _auth = LocalAuthentication();

  /// True when the device has *some* credential set up — a biometric or a
  /// PIN/pattern/passcode. False on a device with no lock at all, where
  /// enabling app lock would leave the user permanently unable to unlock.
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Prompts for the device credential. Returns false — rather than
  /// throwing — for every expected failure (user cancelled, no enrolment,
  /// no passcode set, too many attempts), so callers show a plain retry
  /// instead of an error surface.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Not biometricOnly: the device PIN/pattern/passcode is a valid way
        // in, and is the only way in on a device with no biometric hardware
        // or with a wet/unreadable finger.
        biometricOnly: false,
        // Retry on foregrounding rather than failing outright — the OS
        // backgrounds the app to show the prompt on some Android versions.
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }
}

@Riverpod(keepAlive: true)
AppLockService appLockService(Ref ref) => AppLockService();
