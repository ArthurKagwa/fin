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

  Future<void> deleteExpense(String id);

  /// Clears the soft-delete marker. Deletes are reversible by design so the
  /// UI can offer Undo instead of a confirmation dialog on every correction.
  Future<void> restoreExpense(String id);

  Stream<List<Expense>> watchExpenses({DateTime? month});
}

class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('expenses');

  @override
  Future<Expense> addExpense({
    required String bucketId,
    required int amountMinor,
    required DateTime occurredOn,
    String? payee,
    String? note,
  }) async {
    final doc = await _collection.add({
      'bucketId': bucketId,
      'amountMinor': amountMinor,
      'occurredOn': Timestamp.fromDate(occurredOn),
      'payee': payee,
      'note': note,
      'occurrenceId': null,
      'deletedAt': null,
    });
    final snapshot = await doc.get();
    return _fromDoc(snapshot);
  }

  @override
  Future<void> deleteExpense(String id) =>
      _collection.doc(id).update({'deletedAt': Timestamp.now()});

  @override
  Future<void> restoreExpense(String id) =>
      _collection.doc(id).update({'deletedAt': null});

  @override
  Stream<List<Expense>> watchExpenses({DateTime? month}) {
    Query<Map<String, dynamic>> query = _collection.orderBy('occurredOn', descending: true);
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

@Riverpod(keepAlive: true)
Stream<List<Expense>> recentExpenses(Ref ref) =>
    ref.watch(expenseRepositoryProvider).watchExpenses();
