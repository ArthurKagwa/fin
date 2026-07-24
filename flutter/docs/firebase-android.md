# Firebase & Android-native configuration

Read before touching any Firebase surface. Verify version-specific details against `pubspec.lock`, the Gradle files, and current FlutterFire docs — never from memory.

## Contents
- Project setup & Android native
- Auth
- Firestore
- Storage
- Cloud Messaging (FCM)
- Crashlytics & Analytics
- Remote Config
- Cloud Functions
- App Check
- Security rules
- Emulators

## Project setup & Android native

Configuration lives in generated and native files, and hand-editing the generated ones is a recurring source of "works on my machine":

- `flutterfire configure` generates `lib/firebase_options.dart` and places `android/app/google-services.json`. Re-run it to change projects; never hand-edit either file.
- `google-services.json` is per Firebase project **and per Android package name**. Flavors (dev/staging/prod) need per-flavor files under `android/app/src/<flavor>/` and matching `applicationIdSuffix`. Getting this wrong silently points the dev build at prod data.
- The `com.google.gms.google-services` Gradle plugin must be applied in `android/app/build.gradle(.kts)`. Crashlytics needs its own Gradle plugin on top.
- `minSdk` has a floor set by the current Firebase Android SDK; read what the project declares and check current requirements rather than assuming. Raising it is a product decision (it drops devices) — if the SRD/NFRs state a minimum supported Android version, that governs; if they don't, ask.
- `main()` must `WidgetsFlutterBinding.ensureInitialized()` then `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` before any Firebase call.
- Release builds: R8/ProGuard plus a release `SHA-1`/`SHA-256` registered in the Firebase console for Google Sign-In and App Check. A debug-only SHA is why sign-in "works in debug, fails in release".
- `google-services.json` is not a secret (it ships in the APK), but it is environment-specific. Security comes from rules and App Check, never from hiding this file.

## Auth

- One `AuthRepository` wrapping `FirebaseAuth`. Expose `Stream<AppUser?>`, not `Stream<User?>` — `User` is a Firebase type and must not escape the data layer.
- `authStateChanges()` for gating; `idTokenChanges()` when custom claims drive authorization. Choose deliberately — claims changes don't fire the former.
- Map error codes to domain failures in the repository. Never surface raw codes.
- Enumeration: distinguishing "wrong password" from "no such user" leaks account existence. If the SRD specifies the copy, follow it; if it doesn't and you're about to make that distinction visible, ask.
- Google Sign-In on Android needs SHA fingerprints for every build variant registered in the console.
- Custom claims are set server-side (Functions/Admin SDK) and need a token refresh to appear on the client. Enforce claims in security rules too — a client-side check is a suggestion, not a control.

## Firestore

- **`withConverter<T>` at the collection reference.** Raw `Map<String, dynamic>` in the data layer means every read is an unchecked cast; the converter is the one place a schema change breaks loudly instead of at runtime.
- Model the data for the queries the SDD specifies. Firestore has no joins; denormalize deliberately and record why in the SDD.
- Every compound query needs a composite index — declare it in `firestore.indexes.json` and deploy it. "It works locally" hides missing indexes; production throws.
- Offline persistence is on by default on Android. That means writes succeed locally and sync later, so a UI that shows "saved" is telling the truth only about the local cache. If the SRD makes claims about sync, conflict resolution, or offline behaviour, implement to them; if it's silent and the feature is offline-relevant, that's a question worth stopping for.
- Listeners (`snapshots()`) cost reads on every change and leak if not cancelled — prefer a Riverpod stream provider with `autoDispose` so cancellation is automatic.
- Batches for ≤500 atomic writes; transactions when a write depends on a read. Transactions retry — their callback must be side-effect free.
- Never trust the client for authorization. Rules are the enforcement point.

## Storage

- Path scheme belongs in the SDD (`users/{uid}/avatar.jpg`). Rules depend on path structure, so inventing paths ad hoc means rules can't be written coherently.
- Validate content type and size in rules, not only client-side.
- Store the download URL or the path in Firestore, per what the SDD says; don't do both without reason.
- Uploads need progress and cancellation surfaced as domain state if the docs specify them.

## Cloud Messaging (FCM)

The Android-specific requirements here are where most FCM work goes wrong:

- **Android 13+ requires the runtime `POST_NOTIFICATIONS` permission.** Without it, notifications silently don't appear. Request it at a point the docs specify; if they don't specify when, ask — permission prompt timing is a product decision.
- The background handler must be a **top-level function** annotated `@pragma('vm:entry-point')`, registered before `runApp`. It runs in a separate isolate: no access to app state, and it must initialize Firebase itself.
- Foreground messages do **not** show a system notification automatically on Android. Either display them yourself (e.g. `flutter_local_notifications`) or accept that they're invisible in the foreground — that's a spec question.
- Notification channels are required on modern Android; create the channel and match its id to the payload's `android_channel_id`, or importance settings are ignored.
- Handle all three entry paths: `onMessage`, `onMessageOpenedApp`, and `getInitialMessage` (app launched from terminated by a tap). Missing the third produces "the notification does nothing when the app was closed".
- Tokens rotate. Persist via `onTokenRefresh`, and delete tokens on sign-out or you'll push to the wrong user on shared devices.

## Crashlytics & Analytics

- Wire `FlutterError.onError` and `PlatformDispatcher.instance.onError` to Crashlytics in `main`, or Flutter framework and async errors never reach it.
- Crashlytics needs its Gradle plugin and symbol upload configured for release builds; obfuscated stack traces without symbols are unreadable.
- Debug builds shouldn't pollute production crash data — gate collection by build mode.
- Analytics events: names and parameters come from the docs. Inventing an event taxonomy is inventing requirements — the analytics schema is a product artifact. If the docs are silent, ask.
- Never log PII in analytics parameters or crash keys.

## Remote Config

- Set in-app defaults for every key. A first launch with no network and no defaults gets empty strings.
- `fetchAndActivate()` on startup; treat failure as non-fatal and fall back to defaults.
- `minimumFetchInterval` is throttled in production — a low interval for local testing must not ship.
- Remote Config is not a security control. Anything gated for security goes in rules or server-side.

## Cloud Functions

- `httpsCallable` gives you auth context automatically; prefer it over raw HTTP endpoints unless the SDD says otherwise.
- **Region must match** between deployment and client (`FirebaseFunctions.instanceFor(region: ...)`). A mismatch fails with an opaque `not-found`.
- Map `FirebaseFunctionsException` to domain failures in the repository like any other SDK error.
- Cold starts are real latency. If an NFR states a response time, that's a design constraint, not an implementation detail.
- Validate and authorize inside the function. A callable is a public endpoint.

## App Check

- Debug provider locally (register the debug token), Play Integrity for release. Play Integrity requires the app to be distributed through Play tracks — internal testing counts.
- Register real SHA fingerprints for release, or attestation fails in production only.
- Roll out unenforced first, watch the metrics, then enforce. Enforcing immediately locks out legitimate old clients.

## Security rules

Rules are application code. They belong in the repo (`firestore.rules`, `storage.rules`), in review, and under test.

- A feature touching a new collection or path is **not done** until its rules exist. This is the single most consequential item in the checklist: a client-side app with permissive rules has no access control at all.
- Default deny; grant narrowly. Never `allow read, write: if true` — not even temporarily, because temporary rules ship.
- Rules are not filters. A rule permitting a subset of a collection doesn't make a broad query return fewer docs — it makes the query fail. Design queries and rules together.
- Validate shape and immutability in rules (`request.resource.data.keys()`, unchanged owner fields), not only in Dart.
- Deriving rules requires knowing the access model. If the SRD doesn't state who may read and write what, that's an open question — writing rules from your own guess is inventing security policy.

## Emulators

Use the Firebase Emulator Suite for development and rules tests where the project supports it. Connect via `useFirestoreEmulator`/`useAuthEmulator` guarded by build mode — never let emulator hosts reach a release build.
