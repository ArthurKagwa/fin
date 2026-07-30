import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bucket_repository.g.dart';

abstract class BucketRepository {
  Stream<List<Bucket>> watchActiveBuckets();
  Future<void> createBucket({required String name, int? plannedMinor, int? goalMinor});
  Future<void> updateBucket(
    String id, {
    required String name,
    int? plannedMinor,
    int? goalMinor,
  });
  Future<void> deleteBucket(String id);
}

class FirestoreBucketRepository implements BucketRepository {
  FirestoreBucketRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('buckets');

  @override
  Stream<List<Bucket>> watchActiveBuckets() {
    return _collection
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }

  @override
  Future<void> createBucket({
    required String name,
    int? plannedMinor,
    int? goalMinor,
  }) async {
    final last = await _collection.orderBy('sortOrder', descending: true).limit(1).get();
    final nextSortOrder =
        last.docs.isEmpty ? 0 : (last.docs.first.data()['sortOrder'] as int) + 1;
    await _collection.add({
      'name': name,
      'sortOrder': nextSortOrder,
      'plannedMinor': plannedMinor,
      'goalMinor': goalMinor,
    });
  }

  @override
  Future<void> updateBucket(
    String id, {
    required String name,
    int? plannedMinor,
    int? goalMinor,
  }) =>
      _collection.doc(id).update({
        'name': name,
        'plannedMinor': plannedMinor,
        'goalMinor': goalMinor,
      });

  @override
  Future<void> deleteBucket(String id) => _collection.doc(id).delete();

  Bucket _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Bucket(
      id: doc.id,
      name: data['name'] as String,
      sortOrder: data['sortOrder'] as int,
      plannedMinor: data['plannedMinor'] as int?,
      goalMinor: data['goalMinor'] as int?,
    );
  }
}

@Riverpod(keepAlive: true)
BucketRepository bucketRepository(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('bucketRepository read while signed out');
  return FirestoreBucketRepository(ref.watch(firebaseFirestoreProvider), uid);
}

@Riverpod(keepAlive: true)
Stream<List<Bucket>> activeBuckets(Ref ref) =>
    ref.watch(bucketRepositoryProvider).watchActiveBuckets();
