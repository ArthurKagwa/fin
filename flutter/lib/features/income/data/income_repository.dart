import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'income_repository.g.dart';

abstract class IncomeRepository {
  Stream<List<IncomeEvent>> watchIncomeEvents({DateTime? month});
  Future<IncomeEvent> addIncomeEvent({
    required IncomeKind kind,
    required int amountMinor,
    required DateTime occurredOn,
    required String source,
    int? grossMinor,
    String? note,
    List<({String label, int amountMinor})> deductions = const [],
  });

  Future<void> updateIncomeEvent(
    String id, {
    required IncomeKind kind,
    required int amountMinor,
    required DateTime occurredOn,
    required String source,
    int? grossMinor,
    String? note,
    List<({String label, int amountMinor})> deductions = const [],
  });

  Future<void> deleteIncomeEvent(String id);

  /// Clears the soft-delete marker — same reversible-Undo shape as expense
  /// deletes.
  Future<void> restoreIncomeEvent(String id);
}

class FirestoreIncomeRepository implements IncomeRepository {
  FirestoreIncomeRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _profileDoc =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _profileDoc.collection('incomeEvents');

  @override
  Stream<List<IncomeEvent>> watchIncomeEvents({DateTime? month}) {
    Query<Map<String, dynamic>> query =
        _collection.orderBy('occurredOn', descending: true);
    if (month != null) {
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);
      query = query
          .where('occurredOn', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('occurredOn', isLessThan: Timestamp.fromDate(end));
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(_fromDoc)
              .where((event) => !event.isDeleted)
              .toList(),
        );
  }

  @override
  Future<IncomeEvent> addIncomeEvent({
    required IncomeKind kind,
    required int amountMinor,
    required DateTime occurredOn,
    required String source,
    int? grossMinor,
    String? note,
    List<({String label, int amountMinor})> deductions = const [],
  }) async {
    // A batch, not a transaction: nothing here is read-then-written, so
    // there's no consistency race to protect against — just two writes that
    // must land together.
    final docRef = _collection.doc();
    final batch = _firestore.batch();
    batch.set(docRef, {
      'kind': kind.name,
      'amountMinor': amountMinor,
      'occurredOn': Timestamp.fromDate(occurredOn),
      'source': source,
      'grossMinor': grossMinor,
      'note': note,
      'deductions': [
        for (var i = 0; i < deductions.length; i++)
          {
            'id': '$i',
            'label': deductions[i].label,
            'amountMinor': deductions[i].amountMinor,
            'sortOrder': i,
          },
      ],
      'deletedAt': null,
    });
    batch.update(_profileDoc, {'unallocatedMinor': FieldValue.increment(amountMinor)});
    await batch.commit();
    final snapshot = await docRef.get();
    return _fromDoc(snapshot);
  }

  @override
  Future<void> updateIncomeEvent(
    String id, {
    required IncomeKind kind,
    required int amountMinor,
    required DateTime occurredOn,
    required String source,
    int? grossMinor,
    String? note,
    List<({String label, int amountMinor})> deductions = const [],
  }) async {
    // Callers only reach this for an event with no allocations against it
    // (checked via AllocationRepository.hasAllocationsForIncomeEvent before
    // the edit screen is even opened), so its whole amount is still sitting
    // in unallocatedMinor — the delta just needs folding in.
    final docRef = _collection.doc(id);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final oldAmount = (snapshot.data()?['amountMinor'] as num?)?.toInt() ?? 0;
      final profileSnapshot = await tx.get(_profileDoc);
      final currentUnallocated =
          (profileSnapshot.data()?['unallocatedMinor'] as num?)?.toInt() ?? 0;

      tx.update(docRef, {
        'kind': kind.name,
        'amountMinor': amountMinor,
        'occurredOn': Timestamp.fromDate(occurredOn),
        'source': source,
        'grossMinor': grossMinor,
        'note': note,
        'deductions': [
          for (var i = 0; i < deductions.length; i++)
            {
              'id': '$i',
              'label': deductions[i].label,
              'amountMinor': deductions[i].amountMinor,
              'sortOrder': i,
            },
        ],
      });
      tx.update(_profileDoc, {
        'unallocatedMinor': currentUnallocated - oldAmount + amountMinor,
      });
    });
  }

  @override
  Future<void> deleteIncomeEvent(String id) async {
    final docRef = _collection.doc(id);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data();
      // Idempotency guard: already deleted, don't double-credit-back nothing
      // twice if this somehow runs again.
      if (data == null || data['deletedAt'] != null) return;

      final amountMinor = (data['amountMinor'] as num?)?.toInt() ?? 0;
      tx.update(docRef, {'deletedAt': Timestamp.now()});
      tx.update(_profileDoc, {'unallocatedMinor': FieldValue.increment(-amountMinor)});
    });
  }

  @override
  Future<void> restoreIncomeEvent(String id) async {
    final docRef = _collection.doc(id);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data();
      if (data == null || data['deletedAt'] == null) return;

      final amountMinor = (data['amountMinor'] as num?)?.toInt() ?? 0;
      tx.update(docRef, {'deletedAt': null});
      tx.update(_profileDoc, {'unallocatedMinor': FieldValue.increment(amountMinor)});
    });
  }

  IncomeEvent _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final deductions = (data['deductions'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(
          (d) => Deduction(
            id: d['id'] as String,
            label: d['label'] as String,
            amountMinor: d['amountMinor'] as int,
            sortOrder: d['sortOrder'] as int,
          ),
        )
        .toList();
    return IncomeEvent(
      id: doc.id,
      kind: IncomeKind.values.byName(data['kind'] as String),
      amountMinor: data['amountMinor'] as int,
      occurredOn: (data['occurredOn'] as Timestamp).toDate(),
      source: data['source'] as String,
      grossMinor: data['grossMinor'] as int?,
      note: data['note'] as String?,
      deductions: deductions,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
    );
  }
}

@Riverpod(keepAlive: true)
IncomeRepository incomeRepository(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('incomeRepository read while signed out');
  return FirestoreIncomeRepository(ref.watch(firebaseFirestoreProvider), uid);
}

@Riverpod(keepAlive: true)
Stream<List<IncomeEvent>> incomeEvents(Ref ref) =>
    ref.watch(incomeRepositoryProvider).watchIncomeEvents();

@riverpod
Stream<List<IncomeEvent>> incomeEventsForMonth(Ref ref, DateTime month) =>
    ref.watch(incomeRepositoryProvider).watchIncomeEvents(month: month);
