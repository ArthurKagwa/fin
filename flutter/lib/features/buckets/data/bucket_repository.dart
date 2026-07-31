import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bucket_repository.g.dart';

abstract class BucketRepository {
  /// Unfiltered, ordered by sortOrder. Used by anything that needs
  /// historical reconciliation — plan-vs-actual, the dashboard, the
  /// transactions list, the bucket detail screen — so an archived bucket's
  /// past activity never silently disappears from a month's totals.
  Stream<List<Bucket>> watchAllBuckets();

  /// [watchAllBuckets] minus archived buckets, filtered client-side rather
  /// than via a Firestore query — an `archivedAt == null` filter combined
  /// with `orderBy('sortOrder')` would need a composite index for a
  /// collection this small, which isn't worth it. Used by pickers: you
  /// can't spend into, or point a new recurring payment at, a dead envelope.
  Stream<List<Bucket>> watchActiveBuckets();

  Future<void> createBucket({required String name, int? plannedMinor, int? goalMinor});
  Future<void> updateBucket(
    String id, {
    required String name,
    int? plannedMinor,
    int? goalMinor,
  });

  /// Cheap existence checks — one `.limit(1)` query per referencing
  /// collection, not a full count. True if the bucket is referenced
  /// anywhere, meaning it must be archived rather than hard-deleted.
  Future<bool> hasReferences(String id);

  Future<void> archiveBucket(String id);

  /// The undo for [archiveBucket].
  Future<void> unarchiveBucket(String id);

  /// True hard delete. Callers must call [hasReferences] first and only
  /// invoke this when it returned false — there's a narrow window between
  /// the check and the delete where a new expense could land in between
  /// (Firestore transactions can't run an existence query), accepted as a
  /// low-risk race for a single-user app.
  Future<void> deleteBucket(String id);
}

class FirestoreBucketRepository implements BucketRepository {
  FirestoreBucketRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('buckets');

  CollectionReference<Map<String, dynamic>> get _expenses =>
      _firestore.collection('users').doc(_uid).collection('expenses');

  CollectionReference<Map<String, dynamic>> get _recurringPayments =>
      _firestore.collection('users').doc(_uid).collection('recurringPayments');

  @override
  Stream<List<Bucket>> watchAllBuckets() {
    return _collection
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }

  @override
  Stream<List<Bucket>> watchActiveBuckets() =>
      watchAllBuckets().map((buckets) => buckets.where((b) => !b.isArchived).toList());

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
      'archivedAt': null,
      'balanceMinor': 0,
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
  Future<bool> hasReferences(String id) async {
    final results = await Future.wait([
      _expenses.where('bucketId', isEqualTo: id).limit(1).get(),
      _recurringPayments.where('bucketId', isEqualTo: id).limit(1).get(),
    ]);
    return results.any((snapshot) => snapshot.docs.isNotEmpty);
  }

  @override
  Future<void> archiveBucket(String id) =>
      _collection.doc(id).update({'archivedAt': Timestamp.now()});

  @override
  Future<void> unarchiveBucket(String id) =>
      _collection.doc(id).update({'archivedAt': null});

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
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
      // Pre-existing bucket docs predate this field.
      balanceMinor: (data['balanceMinor'] as num?)?.toInt() ?? 0,
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
Stream<List<Bucket>> allBuckets(Ref ref) =>
    ref.watch(bucketRepositoryProvider).watchAllBuckets();

@Riverpod(keepAlive: true)
Stream<List<Bucket>> activeBuckets(Ref ref) =>
    ref.watch(bucketRepositoryProvider).watchActiveBuckets();

@Riverpod(keepAlive: true)
Stream<List<Bucket>> archivedBuckets(Ref ref) => ref
    .watch(bucketRepositoryProvider)
    .watchAllBuckets()
    .map((buckets) => buckets.where((b) => b.isArchived).toList());
