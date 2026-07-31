import 'package:fintrack/core/utils/currency.dart';
import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/core/widgets/money_field.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs [input] through the formatter one character at a time, the way typing
/// actually reaches it.
String typeDigits(String input, {required String currency}) {
  final formatter = MoneyInputFormatter(currency: currency);
  var value = TextEditingValue.empty;
  for (final char in input.split('')) {
    final next = TextEditingValue(
      text: value.text + char,
      selection: TextSelection.collapsed(offset: value.text.length + 1),
    );
    value = formatter.formatEditUpdate(value, next);
  }
  return value.text;
}

void main() {
  group('currency exponents', () {
    test('most currencies have two decimals', () {
      for (final code in ['USD', 'GBP', 'EUR', 'KES', 'NGN', 'ZAR', 'INR']) {
        expect(currencyDecimals(code), 2, reason: code);
        expect(currencyMinorUnitsPerMajor(code), 100, reason: code);
      }
    });

    test('shillings, francs and yen have none', () {
      for (final code in ['UGX', 'RWF', 'JPY', 'KRW', 'VND', 'XOF']) {
        expect(currencyDecimals(code), 0, reason: code);
        expect(currencyMinorUnitsPerMajor(code), 1, reason: code);
      }
    });

    test('gulf dinars have three', () {
      for (final code in ['KWD', 'BHD', 'OMR', 'TND', 'JOD', 'IQD', 'LYD']) {
        expect(currencyDecimals(code), 3, reason: code);
        expect(currencyMinorUnitsPerMajor(code), 1000, reason: code);
      }
    });

    test('an unknown code falls back to two rather than throwing', () {
      expect(currencyDecimals('ZZZ'), 2);
    });

    test('codes are matched case-insensitively', () {
      expect(currencyDecimals('ugx'), 0);
      expect(currencySymbol('usd'), r'$');
    });
  });

  group('formatMoney', () {
    test('the same integer renders differently per currency', () {
      // The bug this whole change exists to fix: 1200 minor units is twelve
      // dollars but twelve hundred shillings.
      expect(formatMoney(1200, currency: 'USD'), r'$12.00');
      expect(formatMoney(1200, currency: 'UGX'), 'USh 1,200');
      expect(formatMoney(1200, currency: 'KWD'), 'KWD 1.200');
    });

    test('groups thousands in the major part only', () {
      expect(formatMoney(123456789, currency: 'USD'), r'$1,234,567.89');
      expect(formatMoney(123456789, currency: 'UGX'), 'USh 123,456,789');
    });

    test('pads the minor part', () {
      expect(formatMoney(5, currency: 'USD'), r'$0.05');
      expect(formatMoney(50, currency: 'USD'), r'$0.50');
      expect(formatMoney(500, currency: 'USD'), r'$5.00');
      expect(formatMoney(5, currency: 'KWD'), 'KWD 0.005');
    });

    test('zero renders with the currency\'s precision', () {
      expect(formatMoney(0, currency: 'USD'), r'$0.00');
      expect(formatMoney(0, currency: 'UGX'), 'USh 0');
    });

    test('negatives put the sign before the symbol', () {
      expect(formatMoney(-1250, currency: 'USD'), r'-$12.50');
      expect(formatMoney(-1250, currency: 'UGX'), '-USh 1,250');
    });

    test('a symbol sits tight, a code takes a space', () {
      // "UGX1,200" reads as one token; "$12.00" does not need the gap.
      expect(formatMoney(1200, currency: 'USD'), startsWith(r'$1'));
      expect(formatMoney(1200, currency: 'AFN'), 'AFN 12.00');
    });

    test('unknown currencies fall back to the code as the symbol', () {
      expect(formatMoney(1234, currency: 'XYZ'), 'XYZ 12.34');
    });

    test('showDecimals false rounds to the nearest major unit', () {
      expect(formatMoney(1250, currency: 'USD', showDecimals: false), r'$13');
      expect(formatMoney(1249, currency: 'USD', showDecimals: false), r'$12');
      // Rounds rather than truncating, so a column of figures doesn't drift low.
      expect(formatMoney(199, currency: 'USD', showDecimals: false), r'$2');
    });
  });

  group('parseMoney', () {
    test('reads a plain decimal', () {
      expect(parseMoney('12.50', currency: 'USD'), 1250);
      expect(parseMoney('12.5', currency: 'USD'), 1250);
      expect(parseMoney('12', currency: 'USD'), 1200);
    });

    test('ignores grouping separators', () {
      expect(parseMoney('1,234.56', currency: 'USD'), 123456);
      expect(parseMoney('1 234.56', currency: 'USD'), 123456);
    });

    test('treats the last separator as the decimal point', () {
      // European style: 1.234,56 is one thousand two hundred thirty four.
      expect(parseMoney('1.234,56', currency: 'USD'), 123456);
    });

    test('rounds excess precision rather than rejecting it', () {
      expect(parseMoney('12.567', currency: 'USD'), 1257);
      expect(parseMoney('12.564', currency: 'USD'), 1256);
    });

    test('respects zero-decimal currencies', () {
      expect(parseMoney('1200', currency: 'UGX'), 1200);
      expect(parseMoney('1,200', currency: 'UGX'), 1200);
    });

    test('respects three-decimal currencies', () {
      expect(parseMoney('1.234', currency: 'KWD'), 1234);
    });

    test('handles negatives', () {
      expect(parseMoney('-12.50', currency: 'USD'), -1250);
    });

    test('returns null for things that are not numbers', () {
      expect(parseMoney('', currency: 'USD'), isNull);
      expect(parseMoney('abc', currency: 'USD'), isNull);
      expect(parseMoney('12abc', currency: 'USD'), isNull);
    });

    test('round-trips through formatMoney', () {
      for (final currency in ['USD', 'UGX', 'KWD']) {
        for (final amount in [0, 5, 1234, 1000000]) {
          final rendered = formatMoney(amount, currency: currency);
          final stripped = rendered.replaceFirst(currencySymbol(currency), '');
          expect(
            parseMoney(stripped, currency: currency),
            amount,
            reason: '$currency $amount -> $rendered',
          );
        }
      }
    });
  });

  group('cash-register input', () {
    test('digits fill from the right in a two-decimal currency', () {
      expect(typeDigits('1', currency: 'USD'), '0.01');
      expect(typeDigits('12', currency: 'USD'), '0.12');
      expect(typeDigits('125', currency: 'USD'), '1.25');
      expect(typeDigits('1250', currency: 'USD'), '12.50');
      expect(typeDigits('125000', currency: 'USD'), '1,250.00');
    });

    test('collapses to plain digits in a zero-decimal currency', () {
      expect(typeDigits('1', currency: 'UGX'), '1');
      expect(typeDigits('1250', currency: 'UGX'), '1,250');
      expect(typeDigits('1250000', currency: 'UGX'), '1,250,000');
    });

    test('uses three places for a dinar', () {
      expect(typeDigits('1', currency: 'KWD'), '0.001');
      expect(typeDigits('1250', currency: 'KWD'), '1.250');
    });

    test('never includes the currency symbol — the field shows it separately',
        () {
      expect(typeDigits('1250', currency: 'USD'), isNot(contains(r'$')));
      expect(typeDigits('1250', currency: 'UGX'), isNot(contains('USh')));
    });

    test('an empty field stays empty rather than showing zero', () {
      // "Optional amount" fields have to tell cleared apart from zero.
      final formatter = MoneyInputFormatter(currency: 'USD');
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '0.05'),
        TextEditingValue.empty,
      );
      expect(result.text, '');
    });

    test('strips anything that is not a digit', () {
      expect(typeDigits('1a2b5c0', currency: 'USD'), '12.50');
      expect(typeDigits('1.2.5.0', currency: 'USD'), '12.50');
    });

    test('caps length so a held key cannot overflow an int', () {
      final formatter = MoneyInputFormatter(currency: 'USD', maxDigits: 4);
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '123456789'),
      );
      expect(result.text, '12.34');
    });

    test('leaves the caret at the end', () {
      final formatter = MoneyInputFormatter(currency: 'USD');
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1250'),
      );
      expect(result.selection.baseOffset, result.text.length);
    });
  });

  group('reading a field back', () {
    test('recovers the minor units that were typed', () {
      final controller = TextEditingController(
        text: typeDigits('1250', currency: 'USD'),
      );
      expect(moneyFromField(controller), 1250);
      expect(moneyFieldIsEmpty(controller), isFalse);
    });

    test('an empty field is zero and reports itself empty', () {
      final controller = TextEditingController();
      expect(moneyFromField(controller), 0);
      expect(moneyFieldIsEmpty(controller), isTrue);
    });

    test('seeding a field round-trips', () {
      final controller = TextEditingController();
      setMoneyField(controller, 123456, currency: 'USD');
      expect(controller.text, '1,234.56');
      expect(moneyFromField(controller), 123456);
    });

    test('seeding with null clears the field', () {
      final controller = TextEditingController(text: '9.99');
      setMoneyField(controller, null, currency: 'USD');
      expect(controller.text, '');
      expect(moneyFieldIsEmpty(controller), isTrue);
    });

    test('there is no input that produces an unparseable value', () {
      // The silent-null data loss this replaced: int.tryParse('12.50') was
      // null, and null meant "the user left it blank".
      for (final junk in ['12.50', 'abc', '1,2,3', '--5', '9.9.9']) {
        final controller = TextEditingController(
          text: typeDigits(junk, currency: 'USD'),
        );
        expect(moneyFromField(controller), isA<int>());
      }
    });
  });

  group('country to currency', () {
    test('resolves known countries', () {
      expect(currencyForCountry('UG'), 'UGX');
      expect(currencyForCountry('US'), 'USD');
      expect(currencyForCountry('JP'), 'JPY');
      expect(currencyForCountry('KW'), 'KWD');
    });

    test('is case-insensitive', () {
      expect(currencyForCountry('gb'), 'GBP');
    });

    test('returns null for an unknown code instead of throwing', () {
      expect(currencyForCountry('ZZ'), isNull);
    });

    test('every country maps to a currency the formatter can render', () {
      for (final country in supportedCountries) {
        expect(
          () => formatMoney(1234, currency: country.currencyCode),
          returnsNormally,
          reason: country.name,
        );
      }
    });

    test('country codes are unique', () {
      final codes = supportedCountries.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('search matches on name and on currency code', () {
      expect(searchCountries('ugan').single.code, 'UG');
      expect(
        searchCountries('GBP').map((c) => c.code),
        contains('GB'),
      );
      expect(searchCountries('').length, supportedCountries.length);
      expect(searchCountries('zzzzz'), isEmpty);
    });
  });
}
