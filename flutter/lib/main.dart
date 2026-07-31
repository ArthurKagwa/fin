import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:fintrack/core/app_lock/app_lock_controller.dart';
import 'package:fintrack/core/config/google_sign_in_config.dart';
import 'package:fintrack/core/notifications/notification_service.dart';
import 'package:fintrack/core/router/router.dart';
import 'package:fintrack/core/theme/app_theme.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:fintrack/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GoogleSignIn.instance.initialize(
    serverClientId: googleSignInServerClientId.isEmpty
        ? null
        : googleSignInServerClientId,
  );

  // Debug providers under kDebugMode so a local `flutter run` on an emulator
  // (which fails real Play Integrity/App Attest attestation) keeps working.
  // This only makes the client attach tokens — turning on *enforcement*
  // (rejecting unattested requests) is a separate Firebase Console step.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode ? AppleDebugProvider() : AppleAppAttestProvider(),
  );

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ProviderScope(child: FinTrackApp()));
}

class FinTrackApp extends ConsumerStatefulWidget {
  const FinTrackApp({super.key});

  @override
  ConsumerState<FinTrackApp> createState() => _FinTrackAppState();
}

class _FinTrackAppState extends ConsumerState<FinTrackApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-arm the lock the moment the app leaves the foreground, so it's
    // already engaged by the time anything is visible again. `inactive`
    // as well as `paused`: on iOS that's the state during the app switcher,
    // where the snapshot would otherwise show the user's balances.
    //
    // A no-op when app lock is off — the controller checks.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(appLockControllerProvider.notifier).relock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Re-establishes the evening reminder's OS-level schedule on every cold
    // start (and whenever it changes) — cheap insurance against a device
    // reboot having cleared it, without needing a boot-completed receiver.
    ref.listen(userProfileProvider, (_, next) {
      final profile = next.asData?.value;
      if (profile == null) return;
      final service = ref.read(notificationServiceProvider);
      if (profile.hasReminder) {
        service.scheduleDaily(hour: profile.reminderHour!, minute: profile.reminderMinute!);
      } else {
        service.cancel();
      }
    });

    return MaterialApp.router(
      title: 'FinTrack',
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
