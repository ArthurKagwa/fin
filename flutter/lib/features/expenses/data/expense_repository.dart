import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expense_repository.g.dart';

abstract class ExpenseRepository {
  Future<Expense> addExpense({
    required String bucketId,
    required int amountMinor,
    required DateTime occurredOn,
    String? payee,
    String? note,
  });

  Future<void> updateExpense(
    String id, {
    required String bucketId,
    required int amountMinor,
    required DateTime occurredOn,
    String? payee,
    String? note,
  });

  Future<void> deleteExpense(String id);

  /// Clears the soft-delete marker. Deletes are reversible by design so the
  /// UI can offer Undo instead of a confirmation dialog on every correction.
  Future<void> restoreExpense(String id);

  Stream<List<Expense>> watchExpenses({DateTime? month, int? limit});
}

class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('expenses');

  DocumentReference<Map<String, dynamic>> _bucketDoc(String bucketId) =>
      _firestore.collection('users').doc(_uid).collection('buckets').doc(bucketId);

  @override
  Future<Expense> addExpense({
    required String bucketId,
    required int amountMinor,
    required DateTime occurredOn,
    String? payee,
    String? note,
  }) async {
    final docRef = _collection.doc();
    final batch = _firestore.batch();
    batch.set(docRef, {
      'bucketId': bucketId,
      'amountMinor': amountMinor,
      'occurredOn': Timestamp.fromDate(occurredOn),
      'payee': payee,
      'note': note,
      'occurrenceId': null,
      'deletedAt': null,
    });
    batch.update(_bucketDoc(bucketId), {'balanceMinor': FieldValue.increment(-amountMinor)});
    await batch.commit();
    final snapshot = await docRef.get();
    return _fromDoc(snapshot);
  }

  @override
  Future<void> updateExpense(
    String id, {
    required String bucketId,
    required int amountMinor,
    required DateTime occurredOn,
    String? payee,
    String? note,
  }) async {
    final docRef = _collection.doc(id);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data()!;
      final oldBucketId = data['bucketId'] as String;
      final oldAmount = (data['amountMinor'] as num).toInt();

      tx.update(docRef, {
        'bucketId': bucketId,
        'amountMinor': amountMinor,
        'occurredOn': Timestamp.fromDate(occurredOn),
        'payee': payee,
        'note': note,
      });

      if (oldBucketId == bucketId) {
        // Same bucket: only the net difference moves.
        tx.update(_bucketDoc(bucketId), {
          'balanceMinor': FieldValue.increment(oldAmount - amountMinor),
        });
      } else {
        // Different bucket: give the old one its money back, take the new
        // amount from the new one.
        tx.update(_bucketDoc(oldBucketId), {
          'balanceMinor': FieldValue.increment(oldAmount),
        });
        tx.update(_bucketDoc(bucketId), {
          'balanceMinor': FieldValue.increment(-amountMinor),
        });
      }
    });
  }

  @override
  Future<void> deleteExpense(String id) async {
    final docRef = _collection.doc(id);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data();
      if (data == null || data['deletedAt'] != null) return;

      final bucketId = data['bucketId'] as String;
      final amountMinor = (data['amountMinor'] as num).toInt();
      tx.update(docRef, {'deletedAt': Timestamp.now()});
      // Money returns to the bucket it was spent from.
      tx.update(_bucketDoc(bucketId), {'balanceMinor': FieldValue.increment(amountMinor)});
    });
  }

  @override
  Future<void> restoreExpense(String id) async {
    final docRef = _collection.doc(id);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data();
      if (data == null || data['deletedAt'] == null) return;

      final bucketId = data['bucketId'] as String;
      final amountMinor = (data['amountMinor'] as num).toInt();
      tx.update(docRef, {'deletedAt': null});
      tx.update(_bucketDoc(bucketId), {'balanceMinor': FieldValue.increment(-amountMinor)});
    });
  }

  @override
  Stream<List<Expense>> watchExpenses({DateTime? month, int? limit}) {
    Query<Map<String, dynamic>> query = _collection.orderBy('occurredOn', descending: true);
    if (month != null) {
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);
      query = query
          .where('occurredOn', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('occurredOn', isLessThan: Timestamp.fromDate(end));
    }
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(_fromDoc)
              .where((expense) => !expense.isDeleted)
              .toList(),
        );
  }

  Expense _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Expense(
      id: doc.id,
      bucketId: data['bucketId'] as String,
      amountMinor: data['amountMinor'] as int,
      occurredOn: (data['occurredOn'] as Timestamp).toDate(),
      payee: data['payee'] as String?,
      note: data['note'] as String?,
      occurrenceId: data['occurrenceId'] as String?,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
    );
  }
}

@Riverpod(keepAlive: true)
ExpenseRepository expenseRepository(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('expenseRepository read while signed out');
  return FirestoreExpenseRepository(ref.watch(firebaseFirestoreProvider), uid);
}

@riverpod
Stream<List<Expense>> expensesForMonth(Ref ref, DateTime month) =>
    ref.watch(expenseRepositoryProvider).watchExpenses(month: month);

/// Only ever renders the last 5 rows on the dashboard, but reads the whole
/// history without a cap — this bounds it well above what's shown so the
/// query cost stops growing linearly with account age.
@Riverpod(keepAlive: true)
Stream<List<Expense>> recentExpenses(Ref ref) =>
    ref.watch(expenseRepositoryProvider).watchExpenses(limit: 20);
