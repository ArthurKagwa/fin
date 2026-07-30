String formatMoney(int minorUnits, {required String symbol}) {
  final negative = minorUnits < 0;
  final digits = minorUnits.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final sign = negative ? '-' : '';
  return '$sign$symbol ${buffer.toString()}';
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
  return '${date.day}/${date.month}/${date.year}';
}
