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
          for (final dueOn in _occurrenceDates(payment, windowStart, windowEnd)) {
            final id = _occurrenceId(payment.id, dueOn);
            if (resolvedIds.contains(id)) continue;
            occurrences.add(
              Occurrence(
                id: id,
                recurringPaymentId: payment.id,
                dueOn: dueOn,
                expectedMinor: _amountAt(payment, dueOn),
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
    final (paymentId, dueOn) = _parseOccurrenceId(occurrenceId);
    final paymentDoc = await _payments.doc(paymentId).get();
    final payment = _paymentFromDoc(paymentDoc);
    final amountMinor = _amountAt(payment, dueOn);

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
    await batch.commit();
  }

  @override
  Future<void> skipOccurrence(String occurrenceId) async {
    final (paymentId, dueOn) = _parseOccurrenceId(occurrenceId);
    await _occurrenceStatuses.doc(occurrenceId).set({
      'recurringPaymentId': paymentId,
      'dueOn': Timestamp.fromDate(dueOn),
      'status': OccurrenceStatus.skipped.name,
    });
  }

  String _occurrenceId(String paymentId, DateTime dueOn) =>
      '$paymentId::${dueOn.millisecondsSinceEpoch}';

  (String, DateTime) _parseOccurrenceId(String occurrenceId) {
    final parts = occurrenceId.split('::');
    return (parts[0], DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1])));
  }

  int _amountAt(RecurringPayment payment, DateTime date) {
    final active = payment.ratePeriods.where((r) => !r.effectiveFrom.isAfter(date)).toList()
      ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return active.isEmpty ? 0 : active.first.amountMinor;
  }

  List<DateTime> _occurrenceDates(RecurringPayment payment, DateTime windowStart, DateTime windowEnd) {
    final dates = <DateTime>[];
    var cursor = payment.startOn;
    final effectiveEnd = payment.endOn != null && payment.endOn!.isBefore(windowEnd)
        ? payment.endOn!
        : windowEnd;

    while (!cursor.isAfter(effectiveEnd)) {
      if (!cursor.isBefore(windowStart)) dates.add(cursor);
      cursor = _step(payment, cursor);
    }
    return dates;
  }

  DateTime _step(RecurringPayment payment, DateTime from) {
    return switch (payment.frequency) {
      RecurringFrequency.daily => from.add(const Duration(days: 1)),
      RecurringFrequency.weekly => from.add(const Duration(days: 7)),
      RecurringFrequency.biweekly => from.add(const Duration(days: 14)),
      RecurringFrequency.monthly => DateTime(from.year, from.month + 1, from.day),
      RecurringFrequency.yearly => DateTime(from.year + 1, from.month, from.day),
      RecurringFrequency.custom =>
        from.add(Duration(days: payment.intervalDays ?? 30)),
    };
  }

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
