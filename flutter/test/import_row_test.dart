import 'package:fintrack/features/expenses/application/expense.dart';
import 'package:fintrack/features/imports/application/import_row.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense({
  required DateTime occurredOn,
  required int amountMinor,
  String? payee,
}) =>
    Expense(
      id: 'e-${occurredOn.millisecondsSinceEpoch}-$amountMinor',
      bucketId: 'groceries',
      amountMinor: amountMinor,
      occurredOn: occurredOn,
      payee: payee,
    );

void main() {
  group('parseFlexibleDate', () {
    test('parses ISO dates', () {
      expect(parseFlexibleDate('2026-07-04'), DateTime(2026, 7, 4));
    });

    test('treats an unambiguous day-first date as day/month/year', () {
      expect(parseFlexibleDate('25/03/2026'), DateTime(2026, 3, 25));
    });

    test('treats an unambiguous month-first date as month/day/year', () {
      // 13 can't be a day-of-month under 12, so the second field must be
      // the day: this is month/day/year.
      expect(parseFlexibleDate('03/13/2026'), DateTime(2026, 3, 13));
    });

    test('defaults ambiguous dates to day/month/year', () {
      expect(parseFlexibleDate('03/04/2026'), DateTime(2026, 4, 3));
    });

    test('expands a two-digit year', () {
      expect(parseFlexibleDate('01/02/26'), DateTime(2026, 2, 1));
    });

    test('rejects garbage rather than guessing', () {
      expect(parseFlexibleDate('not a date'), isNull);
      expect(parseFlexibleDate(''), isNull);
      expect(parseFlexibleDate('13/13/2026'), isNull);
    });
  });

  group('buildImportRows', () {
    test('parses date, amount and payee columns', () {
      final rows = buildImportRows(
        table: [
          ['Date', 'Amount', 'Description'],
          ['2026-07-01', '12.50', 'Coffee shop'],
        ],
        dateColumn: 0,
        amountColumn: 1,
        payeeColumn: 2,
        hasHeader: true,
        currency: 'USD',
        existing: const [],
      );
      expect(rows, hasLength(1));
      expect(rows.single.occurredOn, DateTime(2026, 7, 1));
      expect(rows.single.amountMinor, 1250);
      expect(rows.single.payee, 'Coffee shop');
      expect(rows.single.isDuplicate, isFalse);
    });

    test('negative amounts (bank exports) become positive spend', () {
      final rows = buildImportRows(
        table: [
          ['2026-07-01', '-12.50'],
        ],
        dateColumn: 0,
        amountColumn: 1,
        hasHeader: false,
        currency: 'USD',
        existing: const [],
      );
      expect(rows.single.amountMinor, 1250);
    });

    test('flags a row matching an existing expense as a duplicate', () {
      final existing = [
        _expense(occurredOn: DateTime(2026, 7, 1), amountMinor: 1250, payee: 'Coffee shop'),
      ];
      final rows = buildImportRows(
        table: [
          ['2026-07-01', '12.50', 'Coffee shop'],
        ],
        dateColumn: 0,
        amountColumn: 1,
        payeeColumn: 2,
        hasHeader: false,
        currency: 'USD',
        existing: existing,
      );
      expect(rows.single.isDuplicate, isTrue);
    });

    test('does not flag a different amount on the same day as a duplicate', () {
      final existing = [
        _expense(occurredOn: DateTime(2026, 7, 1), amountMinor: 1250, payee: 'Coffee shop'),
      ];
      final rows = buildImportRows(
        table: [
          ['2026-07-01', '9.00', 'Coffee shop'],
        ],
        dateColumn: 0,
        amountColumn: 1,
        payeeColumn: 2,
        hasHeader: false,
        currency: 'USD',
        existing: existing,
      );
      expect(rows.single.isDuplicate, isFalse);
    });

    test('a soft-deleted expense is not treated as an existing duplicate', () {
      final existing = [
        Expense(
          id: 'deleted',
          bucketId: 'groceries',
          amountMinor: 1250,
          occurredOn: DateTime(2026, 7, 1),
          payee: 'Coffee shop',
          deletedAt: DateTime(2026, 7, 2),
        ),
      ];
      final rows = buildImportRows(
        table: [
          ['2026-07-01', '12.50', 'Coffee shop'],
        ],
        dateColumn: 0,
        amountColumn: 1,
        payeeColumn: 2,
        hasHeader: false,
        currency: 'USD',
        existing: existing,
      );
      expect(rows.single.isDuplicate, isFalse);
    });

    test('drops rows with an unparseable date or amount instead of throwing', () {
      final rows = buildImportRows(
        table: [
          ['not a date', '12.50'],
          ['2026-07-01', 'not a number'],
          ['2026-07-02', '10.00'],
        ],
        dateColumn: 0,
        amountColumn: 1,
        hasHeader: false,
        currency: 'USD',
        existing: const [],
      );
      expect(rows, hasLength(1));
      expect(rows.single.occurredOn, DateTime(2026, 7, 2));
    });

    test('a zero amount is dropped', () {
      final rows = buildImportRows(
        table: [
          ['2026-07-01', '0.00'],
        ],
        dateColumn: 0,
        amountColumn: 1,
        hasHeader: false,
        currency: 'USD',
        existing: const [],
      );
      expect(rows, isEmpty);
    });

    test('skips the header row when hasHeader is true', () {
      final rows = buildImportRows(
        table: [
          ['Date', 'Amount'],
          ['2026-07-01', '10.00'],
        ],
        dateColumn: 0,
        amountColumn: 1,
        hasHeader: true,
        currency: 'USD',
        existing: const [],
      );
      expect(rows, hasLength(1));
    });
  });
}
