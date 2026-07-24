import 'package:firebase_auth/firebase_auth.dart';
import 'package:fintrack/core/errors/app_failure.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/features/auth/application/app_user.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> createUserWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  Future<void> sendEmailVerification();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map(_mapUser);

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
    } on FirebaseAuthException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
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

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      emailVerified: user.emailVerified,
    );
  }

  AuthFailure _mapError(FirebaseAuthException e) {
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
      _ => const AuthFailure('Something went wrong. Please try again.'),
    };
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    FirebaseAuthRepository(ref.watch(firebaseAuthProvider));

@Riverpod(keepAlive: true)
Stream<AppUser?> authState(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges();
