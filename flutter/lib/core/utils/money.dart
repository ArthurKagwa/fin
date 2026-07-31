import 'package:fintrack/core/utils/currency.dart';

/// Renders an amount held in **minor units** — cents, pence, fils — as text.
///
/// The decimal places come from the currency, not a constant: 1200 is
/// "USh 1,200" in Uganda and "$12.00" in the US, and the same integer is
/// "BD1.200" in Bahrain. Passing the currency is therefore mandatory; there is
/// no sensible default.
///
/// Set [showDecimals] false for a compact reading where the minor part is
/// noise — a chart axis, say. It rounds to the nearest major unit rather than
/// truncating, so totals don't drift downward.
String formatMoney(
  int minorUnits, {
  required String currency,
  bool showDecimals = true,
}) {
  final decimals = currencyDecimals(currency);
  final divisor = currencyMinorUnitsPerMajor(currency);
  final negative = minorUnits < 0;
  final absolute = minorUnits.abs();

  final String body;
  if (decimals == 0) {
    body = _group(absolute.toString());
  } else if (!showDecimals) {
    body = _group(((absolute + divisor ~/ 2) ~/ divisor).toString());
  } else {
    final major = absolute ~/ divisor;
    final minor = absolute % divisor;
    body = '${_group(major.toString())}.${minor.toString().padLeft(decimals, '0')}';
  }

  final symbol = currencySymbol(currency);
  // A glyph sits tight against the number ("$12.00"); a three-letter code
  // needs the gap or it reads as one word ("UGX1,200").
  final separator = currencyHasSymbol(currency) ? '' : ' ';
  return '${negative ? '-' : ''}$symbol$separator$body';
}

/// Groups digits in threes: 1234567 -> 1,234,567.
String _group(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Parses text a person typed into minor units, or null when it isn't a
/// number.
///
/// Accepts grouping separators and either separator as the decimal point, so
/// "1,234.50" and "1.234,50" both work. Extra precision is rounded rather than
/// rejected: someone pasting "12.567" into a two-decimal currency means 12.57,
/// not a validation error.
int? parseMoney(String text, {required String currency}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final negative = trimmed.startsWith('-');
  var body = negative ? trimmed.substring(1) : trimmed;

  final decimals = currencyDecimals(currency);
  final divisor = currencyMinorUnitsPerMajor(currency);

  String whole;
  String fraction;
  if (decimals == 0) {
    // A zero-decimal currency has no fractional part to find, so every
    // separator is grouping — treating the last one as a decimal point would
    // read "1,200" UGX as 1.2 shillings instead of twelve hundred.
    whole = body;
    fraction = '';
  } else {
    // Whichever separator appears last is the decimal point; anything else is
    // grouping.
    final lastDot = body.lastIndexOf('.');
    final lastComma = body.lastIndexOf(',');
    final decimalIndex = lastDot > lastComma ? lastDot : lastComma;
    if (decimalIndex == -1) {
      whole = body;
      fraction = '';
    } else {
      whole = body.substring(0, decimalIndex);
      fraction = body.substring(decimalIndex + 1);
    }
  }

  whole = whole.replaceAll(RegExp(r'[.,\s]'), '');
  if (whole.isEmpty) whole = '0';
  if (!RegExp(r'^\d+$').hasMatch(whole)) return null;
  if (fraction.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fraction)) return null;

  var minor = int.parse(whole) * divisor;
  if (decimals > 0 && fraction.isNotEmpty) {
    // Pad or round the fraction to exactly the currency's precision.
    final padded = fraction.padRight(decimals + 1, '0');
    final kept = int.parse(padded.substring(0, decimals));
    final next = int.parse(padded.substring(decimals, decimals + 1));
    minor += kept + (next >= 5 ? 1 : 0);
  }
  return negative ? -minor : minor;
}

/// "July 2026" — month headings, pickers and statement titles.
String formatMonth(DateTime month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[month.month - 1]} ${month.year}';
}

String relativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  if (diff == -1) return 'yesterday';
  if (diff > 1 && diff <= 14) return 'in $diff days';
  if (diff < -1 && diff >= -14) return '${-diff} days ago';
  return formatDate(date);
}

/// "17 Jul 2026" — the same absolute format everywhere, including the PDF, so
/// a date never changes shape depending on which surface shows it.
String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
