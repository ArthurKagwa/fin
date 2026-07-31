import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/expenses/application/expense.dart';

/// One row parsed out of an imported CSV, ready to become an [Expense] —
/// or flagged as a likely duplicate of one that already exists. Pure Dart:
/// no file IO, no Firestore, so the parsing/dedup logic is unit-testable
/// without a real file or a network call.
class ImportRow {
  const ImportRow({
    required this.rowIndex,
    required this.occurredOn,
    required this.amountMinor,
    this.payee,
    this.isDuplicate = false,
  });

  /// Position in the source file (for error messages) — not shown to the
  /// user in the happy path.
  final int rowIndex;
  final DateTime occurredOn;
  final int amountMinor;
  final String? payee;

  /// Same date + amount + payee as an expense that already exists. Flagged,
  /// not excluded — FR-14 asks for a warning, not a silent skip, since a
  /// genuine repeat purchase at the same place for the same amount is
  /// possible.
  final bool isDuplicate;

  ImportRow copyWith({bool? isDuplicate}) => ImportRow(
        rowIndex: rowIndex,
        occurredOn: occurredOn,
        amountMinor: amountMinor,
        payee: payee,
        isDuplicate: isDuplicate ?? this.isDuplicate,
      );
}

/// Parses common date shells a bank/spreadsheet export uses. Tries ISO first
/// (`DateTime.tryParse` covers `2026-07-04`, `2026-07-04T00:00:00`), then
/// falls back to `/`- or `-`-separated `day/month/year` and `month/day/year`
/// — ambiguous for e.g. `03/04/26`, so day/month/year (the more common
/// convention outside the US) is tried first. Returns null rather than
/// guessing wrong silently.
DateTime? parseFlexibleDate(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final iso = DateTime.tryParse(trimmed);
  if (iso != null) return iso;

  final parts = trimmed.split(RegExp(r'[/\-.]'));
  if (parts.length != 3) return null;
  final numbers = parts.map(int.tryParse).toList();
  if (numbers.any((n) => n == null)) return null;
  final a = numbers[0]!;
  final b = numbers[1]!;
  var year = numbers[2]!;
  if (year < 100) year += 2000;

  // day/month/year if the first field can't be a month.
  if (a > 12 && a <= 31) {
    return _validDate(year, b, a);
  }
  // month/day/year if the second field can't be a month (so the first must
  // be the month).
  if (b > 12 && b <= 31) {
    return _validDate(year, a, b);
  }
  // Both <= 12: genuinely ambiguous. Default to day/month/year.
  return _validDate(year, b, a);
}

DateTime? _validDate(int year, int month, int day) {
  if (month < 1 || month > 12) return null;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  if (day < 1 || day > daysInMonth) return null;
  return DateTime(year, month, day);
}

/// Builds [ImportRow]s from a parsed CSV [table] (as returned by
/// `package:csv`'s decoder — a list of rows, each a list of cell values).
///
/// [dateColumn]/[amountColumn] are required; [payeeColumn] is optional.
/// Rows that fail to parse a valid date or amount are dropped, not thrown —
/// a malformed row in someone's export shouldn't fail the whole import.
List<ImportRow> buildImportRows({
  required List<List<dynamic>> table,
  required int dateColumn,
  required int amountColumn,
  int? payeeColumn,
  required bool hasHeader,
  required String currency,
  required List<Expense> existing,
}) {
  final rows = hasHeader ? table.skip(1).toList() : table;
  final existingKeys = existing
      .where((e) => !e.isDeleted)
      .map((e) => _dedupKey(e.occurredOn, e.amountMinor, e.payee))
      .toSet();

  final result = <ImportRow>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (dateColumn >= row.length || amountColumn >= row.length) continue;

    final date = parseFlexibleDate(row[dateColumn].toString());
    final amount = parseMoney(row[amountColumn].toString(), currency: currency);
    if (date == null || amount == null || amount == 0) continue;

    final payee = (payeeColumn != null && payeeColumn < row.length)
        ? row[payeeColumn].toString().trim()
        : null;
    final amountMinor = amount.abs();

    result.add(
      ImportRow(
        rowIndex: hasHeader ? i + 1 : i,
        occurredOn: date,
        amountMinor: amountMinor,
        payee: (payee?.isEmpty ?? true) ? null : payee,
        isDuplicate: existingKeys.contains(_dedupKey(date, amountMinor, payee)),
      ),
    );
  }
  return result;
}

String _dedupKey(DateTime date, int amountMinor, String? payee) =>
    '${date.year}-${date.month}-${date.day}|$amountMinor|${payee?.trim().toLowerCase() ?? ''}';
