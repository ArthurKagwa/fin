import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/profile/application/user_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_repository.g.dart';

abstract class ProfileRepository {
  Stream<UserProfile?> watchProfile();
  Future<void> setCurrency({required String currencyCode, required String timezone});
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(_uid);

  @override
  Stream<UserProfile?> watchProfile() {
    return _doc.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null || data['currencyCode'] == null) return null;
      return UserProfile(
        currencyCode: data['currencyCode'] as String,
        timezone: data['timezone'] as String,
        currencySetAt: (data['currencySetAt'] as Timestamp).toDate(),
      );
    });
  }

  @override
  Future<void> setCurrency({required String currencyCode, required String timezone}) {
    return _doc.set({
      'currencyCode': currencyCode,
      'timezone': timezone,
      'currencySetAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('profileRepository read while signed out');
  return FirestoreProfileRepository(ref.watch(firebaseFirestoreProvider), uid);
}

@Riverpod(keepAlive: true)
Stream<UserProfile?> userProfile(Ref ref) =>
    ref.watch(profileRepositoryProvider).watchProfile();

@Riverpod(keepAlive: true)
String currencyCode(Ref ref) =>
    ref.watch(userProfileProvider).asData?.value?.currencyCode ?? 'USD';
