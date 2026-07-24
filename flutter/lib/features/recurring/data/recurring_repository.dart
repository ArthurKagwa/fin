import 'package:fintrack/features/recurring/application/recurring_payment.dart';

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

class FirestoreRecurringRepository implements RecurringRepository {
  @override
  Stream<List<RecurringPayment>> watchRecurringPayments() =>
      throw UnimplementedError();

  @override
  Stream<List<Occurrence>> watchUpcomingOccurrences() =>
      throw UnimplementedError();

  @override
  Future<void> createRecurringPayment({
    required String name,
    required String bucketId,
    required RecurringFrequency frequency,
    required int amountMinor,
    required DateTime startOn,
    int? intervalDays,
    DateTime? endOn,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> confirmOccurrence(String occurrenceId) =>
      throw UnimplementedError();

  @override
  Future<void> skipOccurrence(String occurrenceId) =>
      throw UnimplementedError();
}
