import 'package:fintrack/features/recurring/application/recurring_payment.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringPayment _payment({
  required RecurringFrequency frequency,
  required DateTime startOn,
  DateTime? endOn,
  int? intervalDays,
  List<RatePeriod>? ratePeriods,
}) =>
    RecurringPayment(
      id: 'rent',
      name: 'Rent',
      bucketId: 'housing',
      frequency: frequency,
      startOn: startOn,
      endOn: endOn,
      intervalDays: intervalDays,
      ratePeriods: ratePeriods ??
          [RatePeriod(id: 'r1', amountMinor: 100000, effectiveFrom: startOn)],
    );

void main() {
  group('stepOccurrence — month-based steps clamp instead of overflowing', () {
    test('monthly from the 31st lands on the 28th of a non-leap February', () {
      final next = stepOccurrence(
        RecurringFrequency.monthly,
        DateTime(2026, 1, 31),
      );
      expect(next, DateTime(2026, 2, 28));
    });

    test('monthly from the 31st lands on the 29th of a leap February', () {
      final next = stepOccurrence(
        RecurringFrequency.monthly,
        DateTime(2028, 1, 31),
      );
      expect(next, DateTime(2028, 2, 29));
    });

    test('monthly from the 30th lands on the 30th of a 31-day month', () {
      final next = stepOccurrence(
        RecurringFrequency.monthly,
        DateTime(2026, 4, 30),
      );
      expect(next, DateTime(2026, 5, 30));
    });

    test('successive monthly steps from the 31st never drift forward', () {
      var date = DateTime(2026, 1, 31);
      final steps = <DateTime>[];
      for (var i = 0; i < 6; i++) {
        date = stepOccurrence(RecurringFrequency.monthly, date);
        steps.add(date);
      }
      // Jan 31 -> Feb 28 -> Mar 28 -> Apr 28 -> May 28 -> Jun 28 -> Jul 28.
      // The pre-fix behaviour drifted to Mar 3, Jun 3, etc. once it
      // overflowed past a short month.
      expect(steps, [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 28),
        DateTime(2026, 4, 28),
        DateTime(2026, 5, 28),
        DateTime(2026, 6, 28),
        DateTime(2026, 7, 28),
      ]);
    });

    test('yearly from Feb 29 lands on Feb 28 of a non-leap year', () {
      final next = stepOccurrence(
        RecurringFrequency.yearly,
        DateTime(2028, 2, 29),
      );
      expect(next, DateTime(2029, 2, 28));
    });

    test('daily/weekly/biweekly/custom step by fixed durations, unaffected', () {
      expect(
        stepOccurrence(RecurringFrequency.daily, DateTime(2026, 1, 31)),
        DateTime(2026, 2, 1),
      );
      expect(
        stepOccurrence(RecurringFrequency.weekly, DateTime(2026, 1, 31)),
        DateTime(2026, 2, 7),
      );
      expect(
        stepOccurrence(RecurringFrequency.biweekly, DateTime(2026, 1, 31)),
        DateTime(2026, 2, 14),
      );
      expect(
        stepOccurrence(
          RecurringFrequency.custom,
          DateTime(2026, 1, 31),
          intervalDays: 10,
        ),
        DateTime(2026, 2, 10),
      );
    });
  });

  group('amountAt', () {
    test('returns the most recent rate effective on or before the date', () {
      final payment = _payment(
        frequency: RecurringFrequency.monthly,
        startOn: DateTime(2026, 1, 1),
        ratePeriods: [
          RatePeriod(id: 'r1', amountMinor: 100000, effectiveFrom: DateTime(2026, 1, 1)),
          RatePeriod(id: 'r2', amountMinor: 120000, effectiveFrom: DateTime(2026, 6, 1)),
        ],
      );
      expect(amountAt(payment, DateTime(2026, 3, 1)), 100000);
      expect(amountAt(payment, DateTime(2026, 6, 1)), 120000);
      expect(amountAt(payment, DateTime(2026, 12, 1)), 120000);
    });
  });

  group('occurrenceDates', () {
    test('includes only dates within the window', () {
      final payment = _payment(
        frequency: RecurringFrequency.monthly,
        startOn: DateTime(2026, 1, 31),
      );
      final dates = occurrenceDates(
        payment,
        DateTime(2026, 2, 1),
        DateTime(2026, 5, 1),
      );
      expect(dates, [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 28),
        DateTime(2026, 4, 28),
      ]);
    });

    test('stops at endOn even if the window extends further', () {
      final payment = _payment(
        frequency: RecurringFrequency.monthly,
        startOn: DateTime(2026, 1, 1),
        endOn: DateTime(2026, 3, 1),
      );
      final dates = occurrenceDates(
        payment,
        DateTime(2026, 1, 1),
        DateTime(2026, 6, 1),
      );
      expect(dates, [
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      ]);
    });
  });
}
