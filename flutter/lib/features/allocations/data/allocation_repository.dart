import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintrack/core/errors/app_failure.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'allocation_repository.g.dart';

abstract class AllocationRepository {
  /// Moves money out of the unallocated pool and into a bucket's balance.
  /// Rejects (as a [ConflictFailure]) if [amountMinor] exceeds what's
  /// currently unallocated.
  Future<void> allocate({
    required String incomeEventId,
    required String bucketId,
    required int amountMinor,
  });

  /// True if any allocation was ever recorded against this income event —
  /// the gate for editing/deleting it (see `IncomeRepository`).
  Future<bool> hasAllocationsForIncomeEvent(String incomeEventId);
}

class FirestoreAllocationRepository implements AllocationRepository {
  FirestoreAllocationRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _profileDoc =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _allocations =>
      _profileDoc.collection('allocations');

  DocumentReference<Map<String, dynamic>> _bucketDoc(String bucketId) =>
      _profileDoc.collection('buckets').doc(bucketId);

  @override
  Future<void> allocate({
    required String incomeEventId,
    required String bucketId,
    required int amountMinor,
  }) async {
    if (amountMinor <= 0) return;
    await _firestore.runTransaction((tx) async {
      final profileSnapshot = await tx.get(_profileDoc);
      final currentUnallocated =
          (profileSnapshot.data()?['unallocatedMinor'] as num?)?.toInt() ?? 0;
      if (amountMinor > currentUnallocated) {
        throw const ConflictFailure('That\'s more than you have unallocated.');
      }

      final bucketRef = _bucketDoc(bucketId);
      final bucketSnapshot = await tx.get(bucketRef);
      final currentBalance =
          (bucketSnapshot.data()?['balanceMinor'] as num?)?.toInt() ?? 0;

      tx.set(_allocations.doc(), {
        'incomeEventId': incomeEventId,
        'bucketId': bucketId,
        'amountMinor': amountMinor,
        'createdAt': Timestamp.now(),
      });
      tx.update(_profileDoc, {'unallocatedMinor': currentUnallocated - amountMinor});
      tx.update(bucketRef, {'balanceMinor': currentBalance + amountMinor});
    });
  }

  @override
  Future<bool> hasAllocationsForIncomeEvent(String incomeEventId) async {
    final snapshot = await _allocations
        .where('incomeEventId', isEqualTo: incomeEventId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}

@Riverpod(keepAlive: true)
AllocationRepository allocationRepository(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('allocationRepository read while signed out');
  return FirestoreAllocationRepository(ref.watch(firebaseFirestoreProvider), uid);
}
