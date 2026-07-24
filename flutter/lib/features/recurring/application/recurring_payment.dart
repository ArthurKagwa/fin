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

  int get currentAmountMinor {
    final now = DateTime.now();
    final active = ratePeriods
        .where((r) => !r.effectiveFrom.isAfter(now))
        .toList()
      ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return active.isEmpty ? 0 : active.first.amountMinor;
  }
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
