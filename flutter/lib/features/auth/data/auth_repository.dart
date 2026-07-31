import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fintrack/core/errors/app_failure.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/features/auth/application/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

/// Which provider the current session most recently authenticated with —
/// determines which re-auth flow [AuthRepository.deleteAccount] needs if
/// Firebase rejects it as [ReauthRequiredFailure].
enum SignInProviderKind { password, google, unknown }

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> createUserWithEmailAndPassword(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<void> sendEmailVerification();
  Future<void> reloadCurrentUser();

  SignInProviderKind currentProviderKind();
  Future<void> reauthenticateWithPassword(String password);
  Future<void> reauthenticateWithGoogle();

  /// Deletes every Firestore document under `users/{uid}` and then the
  /// Firebase Auth account itself. Irreversible. Throws
  /// [ReauthRequiredFailure] if the session is too old — the caller should
  /// re-authenticate (see [currentProviderKind]) and call this again.
  Future<void> deleteAccount();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._googleSignIn, this._firestore);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  @override
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map(_mapUser);

  @override
  Future<void> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      throw const AuthFailure('Google sign-in failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> reloadCurrentUser() async {
    try {
      await _auth.currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  SignInProviderKind currentProviderKind() {
    final providers =
        _auth.currentUser?.providerData.map((p) => p.providerId) ?? const <String>[];
    if (providers.contains('google.com')) return SignInProviderKind.google;
    if (providers.contains('password')) return SignInProviderKind.password;
    return SignInProviderKind.unknown;
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthFailure('You need to sign in again.');
    }
    try {
      final credential =
          EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('You need to sign in again.');
    try {
      final account = await _googleSignIn.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      throw const AuthFailure('Google sign-in failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _deleteUserData(user.uid);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  /// Every subcollection under `users/{uid}` — kept as an explicit list
  /// rather than discovered dynamically, since the client SDK has no
  /// "list subcollections" call; a new feature's collection must be added
  /// here or its data survives account deletion as an orphan.
  static const _userSubcollections = [
    'buckets',
    'expenses',
    'incomeEvents',
    'recurringPayments',
    'occurrenceStatuses',
    'monthlyPlans',
    'allocations',
  ];

  Future<void> _deleteUserData(String uid) async {
    final userDoc = _firestore.collection('users').doc(uid);
    for (final name in _userSubcollections) {
      await _deleteCollection(userDoc.collection(name));
    }
    await userDoc.delete();
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> collection) async {
    // Paged, batched deletes — a batch tops out at 500 writes, so this
    // works regardless of how large a collection has grown.
    const pageSize = 400;
    while (true) {
      final snapshot = await collection.limit(pageSize).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < pageSize) return;
    }
  }

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      emailVerified: user.emailVerified,
      createdAt: user.metadata.creationTime,
    );
  }

  AppFailure _mapError(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        const AuthFailure('Email or password is incorrect.'),
      'email-already-in-use' =>
        const AuthFailure('An account with this email already exists.'),
      'weak-password' =>
        const AuthFailure('Password must be at least 10 characters.'),
      'invalid-email' => const AuthFailure('Please enter a valid email.'),
      'too-many-requests' =>
        const AuthFailure('Too many attempts. Please try again later.'),
      'requires-recent-login' => const ReauthRequiredFailure(
          'Please confirm it\'s you before deleting your account.',
        ),
      _ => const AuthFailure('Something went wrong. Please try again.'),
    };
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => FirebaseAuthRepository(
      ref.watch(firebaseAuthProvider),
      ref.watch(googleSignInProvider),
      ref.watch(firebaseFirestoreProvider),
    );

@Riverpod(keepAlive: true)
Stream<AppUser?> authState(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges();

@Riverpod(keepAlive: true)
String? currentUid(Ref ref) => ref.watch(authStateProvider).asData?.value?.id;
