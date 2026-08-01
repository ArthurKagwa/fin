enum RecurringFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  yearly,
  custom,
}

class RatePeriod {
  const RatePeriod({
    required this.id,
    required this.amountMinor,
    required this.effectiveFrom,
  });

  final String id;
  final int amountMinor;
  final DateTime effectiveFrom;
}

class RecurringPayment {
  const RecurringPayment({
    required this.id,
    required this.name,
    required this.bucketId,
    required this.frequency,
    required this.startOn,
    required this.ratePeriods,
    this.intervalDays,
    this.endOn,
  });

  final String id;
  final String name;
  final String bucketId;
  final RecurringFrequency frequency;
  final int? intervalDays;
  final DateTime startOn;
  final DateTime? endOn;
  final List<RatePeriod> ratePeriods;

  int get currentAmountMinor => amountAt(this, DateTime.now());
}

enum OccurrenceStatus { pending, confirmed, skipped, linked }

class Occurrence {
  const Occurrence({
    required this.id,
    required this.recurringPaymentId,
    required this.dueOn,
    required this.expectedMinor,
    required this.status,
  });

  final String id;
  final String recurringPaymentId;
  final DateTime dueOn;
  final int expectedMinor;
  final OccurrenceStatus status;
}

/// The stable id of the occurrence of [paymentId] due on [dueOn].
///
/// Occurrences are generated on the fly rather than stored, so this — not a
/// document id — is what links a due date to the status doc and to the expense
/// a confirmation writes. Pure and shared so that anything reasoning about
/// occurrences (projections included) derives the same id the repository does.
String occurrenceIdFor(String paymentId, DateTime dueOn) =>
    '$paymentId::${dueOn.millisecondsSinceEpoch}';

/// Inverse of [occurrenceIdFor].
(String, DateTime) parseOccurrenceId(String occurrenceId) {
  final parts = occurrenceId.split('::');
  return (parts[0], DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1])));
}

/// The rate in effect for [payment] on [date] — the most recent [RatePeriod]
/// whose `effectiveFrom` is not after [date]. Pure so it's unit-testable
/// without a Firestore document round-trip.
int amountAt(RecurringPayment payment, DateTime date) {
  final active = payment.ratePeriods.where((r) => !r.effectiveFrom.isAfter(date)).toList()
    ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
  return active.isEmpty ? 0 : active.first.amountMinor;
}

/// Advances [from] by one occurrence of [frequency] (`custom` steps by
/// [intervalDays], default 30 if unset).
///
/// Month-based steps (`monthly`, `yearly`) clamp the day to the target
/// month's last day instead of letting `DateTime`'s constructor silently
/// overflow it into the following month — a payment due on the 31st steps to
/// the 28th/29th/30th of a short month, not to the 1st-3rd of the month
/// after, which was drifting every subsequent occurrence.
DateTime stepOccurrence(
  RecurringFrequency frequency,
  DateTime from, {
  int? intervalDays,
}) {
  return switch (frequency) {
    RecurringFrequency.daily => from.add(const Duration(days: 1)),
    RecurringFrequency.weekly => from.add(const Duration(days: 7)),
    RecurringFrequency.biweekly => from.add(const Duration(days: 14)),
    RecurringFrequency.monthly => _addMonthsClamped(from, 1),
    RecurringFrequency.yearly => _addMonthsClamped(from, 12),
    RecurringFrequency.custom => from.add(Duration(days: intervalDays ?? 30)),
  };
}

DateTime _addMonthsClamped(DateTime from, int months) {
  final totalMonths = from.year * 12 + (from.month - 1) + months;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
  final day = from.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : from.day;
  return DateTime(year, month, day);
}

/// Due-dates for [payment] that fall within `[windowStart, windowEnd]`
/// (both inclusive), stepping from `payment.startOn`. Pure — no Firestore.
List<DateTime> occurrenceDates(
  RecurringPayment payment,
  DateTime windowStart,
  DateTime windowEnd,
) {
  final dates = <DateTime>[];
  var cursor = payment.startOn;
  final effectiveEnd = payment.endOn != null && payment.endOn!.isBefore(windowEnd)
      ? payment.endOn!
      : windowEnd;

  while (!cursor.isAfter(effectiveEnd)) {
    if (!cursor.isBefore(windowStart)) dates.add(cursor);
    cursor = stepOccurrence(payment.frequency, cursor, intervalDays: payment.intervalDays);
  }
  return dates;
}
