import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/core/utils/combine_latest.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/recurring/application/recurring_payment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recurring_repository.g.dart';

abstract class RecurringRepository {
  Stream<List<RecurringPayment>> watchRecurringPayments();
  Stream<List<Occurrence>> watchUpcomingOccurrences();
  Future<void> createRecurringPayment({
    required String name,
    required String bucketId,
    required RecurringFrequency frequency,
    required int amountMinor,
    required DateTime startOn,
    int? intervalDays,
    DateTime? endOn,
  });
  Future<void> confirmOccurrence(String occurrenceId);
  Future<void> skipOccurrence(String occurrenceId);

  /// Renames the payment or moves future occurrences to a different bucket.
  /// Doesn't touch rate-period history or dates.
  Future<void> updateDetails(String id, {required String name, required String bucketId});

  /// Records an amount change effective from a date — the missing write path
  /// for the rate-period history the model already supports.
  Future<void> addRatePeriod(String id, {required int amountMinor, required DateTime effectiveFrom});

  /// Sets or clears the end date. This is the primary "stop this payment"
  /// action — occurrences are generated on the fly from `startOn`/`endOn`, so
  /// setting `endOn` to now (or to a past date) is enough to stop generating
  /// future ones; past confirmed occurrences are separate expense docs and
  /// are unaffected.
  Future<void> setEndDate(String id, DateTime? endOn);

  /// True if any expense was ever created from an occurrence of this payment
  /// (via [confirmOccurrence]) — existence check, not a count.
  Future<bool> hasLinkedExpenses(String id);

  /// True hard delete. Callers should only invoke this when
  /// [hasLinkedExpenses] returned false; otherwise [setEndDate] is the safe
  /// "stop it" action that preserves history.
  Future<void> deleteRecurringPayment(String id);
}

const _lookback = Duration(days: 30);
const _lookahead = Duration(days: 14);

class FirestoreRecurringRepository implements RecurringRepository {
  FirestoreRecurringRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('users').doc(_uid).collection('recurringPayments');

  CollectionReference<Map<String, dynamic>> get _occurrenceStatuses =>
      _firestore.collection('users').doc(_uid).collection('occurrenceStatuses');

  CollectionReference<Map<String, dynamic>> get _expenses =>
      _firestore.collection('users').doc(_uid).collection('expenses');

  DocumentReference<Map<String, dynamic>> _bucketDoc(String bucketId) =>
      _firestore.collection('users').doc(_uid).collection('buckets').doc(bucketId);

  @override
  Stream<List<RecurringPayment>> watchRecurringPayments() {
    return _payments.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs.map(_paymentFromDoc).toList(),
        );
  }

  @override
  Stream<List<Occurrence>> watchUpcomingOccurrences() {
    return combineLatest2(
      _payments.snapshots(),
      _occurrenceStatuses.snapshots(),
      (
        QuerySnapshot<Map<String, dynamic>> paymentsSnapshot,
        QuerySnapshot<Map<String, dynamic>> statusesSnapshot,
      ) {
        final resolvedIds = statusesSnapshot.docs.map((d) => d.id).toSet();
        final now = DateTime.now();
        final windowStart = now.subtract(_lookback);
        final windowEnd = now.add(_lookahead);

        final occurrences = <Occurrence>[];
        for (final doc in paymentsSnapshot.docs) {
          final payment = _paymentFromDoc(doc);
          for (final dueOn in occurrenceDates(payment, windowStart, windowEnd)) {
            final id = occurrenceIdFor(payment.id, dueOn);
            if (resolvedIds.contains(id)) continue;
            occurrences.add(
              Occurrence(
                id: id,
                recurringPaymentId: payment.id,
                dueOn: dueOn,
                expectedMinor: amountAt(payment, dueOn),
                status: OccurrenceStatus.pending,
              ),
            );
          }
        }
        occurrences.sort((a, b) => a.dueOn.compareTo(b.dueOn));
        return occurrences;
      },
    );
  }

  @override
  Future<void> createRecurringPayment({
    required String name,
    required String bucketId,
    required RecurringFrequency frequency,
    required int amountMinor,
    required DateTime startOn,
    int? intervalDays,
    DateTime? endOn,
  }) {
    final ratePeriodId = _payments.doc().id;
    return _payments.add({
      'name': name,
      'bucketId': bucketId,
      'frequency': frequency.name,
      'intervalDays': intervalDays,
      'startOn': Timestamp.fromDate(startOn),
      'endOn': endOn == null ? null : Timestamp.fromDate(endOn),
      'ratePeriods': [
        {
          'id': ratePeriodId,
          'amountMinor': amountMinor,
          'effectiveFrom': Timestamp.fromDate(startOn),
        },
      ],
    });
  }

  @override
  Future<void> confirmOccurrence(String occurrenceId) async {
    final (paymentId, dueOn) = parseOccurrenceId(occurrenceId);
    final paymentDoc = await _payments.doc(paymentId).get();
    final payment = _paymentFromDoc(paymentDoc);
    final amountMinor = amountAt(payment, dueOn);

    final batch = _firestore.batch();
    batch.set(_occurrenceStatuses.doc(occurrenceId), {
      'recurringPaymentId': paymentId,
      'dueOn': Timestamp.fromDate(dueOn),
      'status': OccurrenceStatus.confirmed.name,
    });
    batch.set(_expenses.doc(), {
      'bucketId': payment.bucketId,
      'amountMinor': amountMinor,
      'occurredOn': Timestamp.fromDate(dueOn),
      'payee': payment.name,
      'note': null,
      'occurrenceId': occurrenceId,
      'deletedAt': null,
    });
    // Same accounting as ExpenseRepository.addExpense — this is the one path
    // that creates an expense without going through it.
    batch.update(_bucketDoc(payment.bucketId), {
      'balanceMinor': FieldValue.increment(-amountMinor),
    });
    await batch.commit();
  }

  @override
  Future<void> skipOccurrence(String occurrenceId) async {
    final (paymentId, dueOn) = parseOccurrenceId(occurrenceId);
    await _occurrenceStatuses.doc(occurrenceId).set({
      'recurringPaymentId': paymentId,
      'dueOn': Timestamp.fromDate(dueOn),
      'status': OccurrenceStatus.skipped.name,
    });
  }

  @override
  Future<void> updateDetails(String id, {required String name, required String bucketId}) =>
      _payments.doc(id).update({'name': name, 'bucketId': bucketId});

  @override
  Future<void> addRatePeriod(
    String id, {
    required int amountMinor,
    required DateTime effectiveFrom,
  }) async {
    final ratePeriodId = _payments.doc().id;
    await _payments.doc(id).update({
      'ratePeriods': FieldValue.arrayUnion([
        {
          'id': ratePeriodId,
          'amountMinor': amountMinor,
          'effectiveFrom': Timestamp.fromDate(effectiveFrom),
        },
      ]),
    });
  }

  @override
  Future<void> setEndDate(String id, DateTime? endOn) => _payments
      .doc(id)
      .update({'endOn': endOn == null ? null : Timestamp.fromDate(endOn)});

  @override
  Future<bool> hasLinkedExpenses(String id) async {
    final prefix = '$id::';
    final snapshot = await _expenses
        .where('occurrenceId', isGreaterThanOrEqualTo: prefix)
        .where('occurrenceId', isLessThan: '$prefix')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  @override
  Future<void> deleteRecurringPayment(String id) => _payments.doc(id).delete();

  RecurringPayment _paymentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final ratePeriods = (data['ratePeriods'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (r) => RatePeriod(
            id: r['id'] as String,
            amountMinor: r['amountMinor'] as int,
            effectiveFrom: (r['effectiveFrom'] as Timestamp).toDate(),
          ),
        )
        .toList();
    return RecurringPayment(
      id: doc.id,
      name: data['name'] as String,
      bucketId: data['bucketId'] as String,
      frequency: RecurringFrequency.values.byName(data['frequency'] as String),
      intervalDays: data['intervalDays'] as int?,
      startOn: (data['startOn'] as Timestamp).toDate(),
      endOn: (data['endOn'] as Timestamp?)?.toDate(),
      ratePeriods: ratePeriods,
    );
  }
}

@Riverpod(keepAlive: true)
RecurringRepository recurringRepository(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('recurringRepository read while signed out');
  return FirestoreRecurringRepository(ref.watch(firebaseFirestoreProvider), uid);
}

@Riverpod(keepAlive: true)
Stream<List<RecurringPayment>> recurringPayments(Ref ref) =>
    ref.watch(recurringRepositoryProvider).watchRecurringPayments();

@Riverpod(keepAlive: true)
Stream<List<Occurrence>> upcomingOccurrences(Ref ref) =>
    ref.watch(recurringRepositoryProvider).watchUpcomingOccurrences();
