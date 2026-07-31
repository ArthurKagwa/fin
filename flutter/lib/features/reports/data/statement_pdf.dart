import 'dart:typed_data';

import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:fintrack/features/reports/application/monthly_statement.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Sampled from the app's editorial palette so a printed statement is
// recognisably the same product. Duplicated rather than imported from
// AppColors because those are Flutter `Color`s and this layer must not depend
// on the widget library.
const _ink = PdfColor.fromInt(0xFF1D1B19);
const _muted = PdfColor.fromInt(0xFF57423D);
const _rule = PdfColor.fromInt(0xFFDED9D6);
const _terracotta = PdfColor.fromInt(0xFFA53B26);
const _green = PdfColor.fromInt(0xFF376847);
const _bandFill = PdfColor.fromInt(0xFFF2EDE9);

/// Renders a month's statement to PDF bytes.
///
/// Deliberately built from primitives (Row/Column/Container) rather than the
/// package's table helpers: those have moved between major versions, and a
/// statement's columns need per-column alignment anyway.
Future<Uint8List> buildStatementPdf(MonthlyStatement statement) async {
  final doc = pw.Document(
    title: 'FinTrack statement ${formatMonth(statement.month)}',
  );
  final currency = statement.currency;
  final report = statement.report;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 48),
      header: (context) =>
          context.pageNumber == 1 ? _header(statement) : _runningHeader(statement),
      footer: (context) => _footer(context),
      build: (context) => [
        _sectionTitle('Summary'),
        _summaryBlock(statement),
        pw.SizedBox(height: 24),
        _sectionTitle('Money in'),
        if (report.incomeSources.isEmpty)
          _note('No expected income was set for this month.')
        else
          _incomeSourceTable(report, currency),
        pw.SizedBox(height: 8),
        _incomeEventTable(statement),
        pw.SizedBox(height: 24),
        _sectionTitle('Money out by bucket'),
        if (statement.bucketLines.isEmpty)
          _note('Nothing was planned or spent this month.')
        else
          _bucketTable(statement),
        if (statement.untouchedBucketCount > 0) ...[
          pw.SizedBox(height: 6),
          _note(
            '${statement.untouchedBucketCount} further '
            '${statement.untouchedBucketCount == 1 ? 'bucket had' : 'buckets had'} '
            'no plan and no spend.',
          ),
        ],
        pw.SizedBox(height: 24),
        _sectionTitle('Transactions'),
        if (statement.expenses.isEmpty)
          _note('No expenses were logged this month.')
        else
          _transactionTable(statement),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _header(MonthlyStatement statement) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 24),
    padding: const pw.EdgeInsets.only(bottom: 12),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 1)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'FinTrack',
              style: pw.TextStyle(
                fontSize: 10,
                color: _terracotta,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              formatMonth(statement.month),
              style: pw.TextStyle(
                fontSize: 26,
                color: _ink,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Statement',
              style: const pw.TextStyle(fontSize: 10, color: _muted),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated ${formatDate(statement.generatedAt)}',
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
            pw.Text(
              'Amounts in ${statement.currency}',
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _runningHeader(MonthlyStatement statement) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 16),
    child: pw.Text(
      'FinTrack  -  ${formatMonth(statement.month)}',
      style: const pw.TextStyle(fontSize: 9, color: _muted),
    ),
  );
}

pw.Widget _footer(pw.Context context) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 12),
    child: pw.Text(
      'Page ${context.pageNumber} of ${context.pagesCount}',
      style: const pw.TextStyle(fontSize: 9, color: _muted),
    ),
  );
}

pw.Widget _sectionTitle(String text) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Text(
      text.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        color: _muted,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
  );
}

pw.Widget _note(String text) {
  return pw.Text(text, style: const pw.TextStyle(fontSize: 10, color: _muted));
}

pw.Widget _summaryBlock(MonthlyStatement statement) {
  final report = statement.report;
  final currency = statement.currency;
  final leftToSpend = report.leftToSpendMinor;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: const pw.BoxDecoration(color: _bandFill),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _bigStat(
              label: leftToSpend < 0 ? 'Over plan by' : 'Left to spend',
              value: formatMoney(leftToSpend.abs(), currency: currency),
              color: leftToSpend < 0 ? _terracotta : _ink,
            ),
            _bigStat(
              label: 'Received',
              value: formatMoney(report.income.actualMinor, currency: currency),
              color: _green,
            ),
            _bigStat(
              label: 'Spent',
              value: formatMoney(report.spend.actualMinor, currency: currency),
              color: _ink,
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 14),
      _statRow(
        'Expected income',
        formatMoney(report.income.plannedMinor, currency: currency),
      ),
      _statRow(
        'Income received',
        formatMoney(report.income.actualMinor, currency: currency),
      ),
      _statRow(
        'Planned spend',
        formatMoney(report.spend.plannedMinor, currency: currency),
      ),
      _statRow(
        'Actual spend',
        formatMoney(report.spend.actualMinor, currency: currency),
      ),
      _statRow(
        'Net cash',
        formatMoney(report.netCashMinor, currency: currency),
        emphasise: true,
      ),
      if (!report.plan.isSnapshot) ...[
        pw.SizedBox(height: 10),
        _note(
          'No plan was recorded for this month. Planned figures above are the '
          'bucket amounts currently set.',
        ),
      ],
    ],
  );
}

pw.Widget _bigStat({
  required String label,
  required String value,
  required PdfColor color,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
      pw.SizedBox(height: 4),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 16,
          color: color,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );
}

pw.Widget _statRow(String label, String value, {bool emphasise = false}) {
  final style = pw.TextStyle(
    fontSize: 10,
    color: _ink,
    fontWeight: emphasise ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: emphasise ? _ink : _muted,
            fontWeight: emphasise ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(value, style: style),
      ],
    ),
  );
}

pw.Widget _tableHeader(List<String> labels, List<int> flexes) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.8)),
    ),
    child: pw.Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          pw.Expanded(
            flex: flexes[i],
            child: pw.Text(
              labels[i],
              textAlign: i == 0 ? pw.TextAlign.left : pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 8,
                color: _muted,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
      ],
    ),
  );
}

pw.Widget _tableRow(
  List<String> cells,
  List<int> flexes, {
  PdfColor? lastCellColor,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.5)),
    ),
    child: pw.Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          pw.Expanded(
            flex: flexes[i],
            child: pw.Text(
              cells[i],
              textAlign: i == 0 ? pw.TextAlign.left : pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9.5,
                color: i == cells.length - 1 ? (lastCellColor ?? _ink) : _ink,
              ),
            ),
          ),
      ],
    ),
  );
}

pw.Widget _incomeSourceTable(PlanVsActual report, String currency) {
  const flexes = [4, 3, 3, 3];
  return pw.Column(
    children: [
      _tableHeader(const ['Source', 'Expected', 'Received', 'Difference'], flexes),
      for (final source in report.incomeSources)
        _tableRow(
          [
            source.label,
            source.isUnplanned
                ? '-'
                : formatMoney(source.expectedMinor, currency: currency),
            formatMoney(source.actualMinor, currency: currency),
            source.isUnplanned
                ? '-'
                : _signed(source.varianceMinor, currency),
          ],
          flexes,
          lastCellColor: source.isUnplanned
              ? _muted
              : (source.varianceMinor < 0 ? _terracotta : _green),
        ),
    ],
  );
}

pw.Widget _incomeEventTable(MonthlyStatement statement) {
  final events = statement.incomeInDateOrder;
  if (events.isEmpty) return pw.SizedBox();
  final currency = statement.currency;
  const flexes = [3, 4, 3, 3, 3];

  return pw.Column(
    children: [
      pw.SizedBox(height: 12),
      _tableHeader(
        const ['Date', 'Source', 'Gross', 'Deductions', 'Take-home'],
        flexes,
      ),
      for (final event in events)
        _tableRow(
          [
            formatDate(event.occurredOn),
            event.source,
            formatMoney(event.grossMinor ?? event.amountMinor, currency: currency),
            event.deductionsTotalMinor == 0
                ? '-'
                : formatMoney(event.deductionsTotalMinor, currency: currency),
            formatMoney(event.amountMinor, currency: currency),
          ],
          flexes,
          lastCellColor: _green,
        ),
    ],
  );
}

pw.Widget _bucketTable(MonthlyStatement statement) {
  final currency = statement.currency;
  const flexes = [4, 3, 3, 3];

  return pw.Column(
    children: [
      _tableHeader(const ['Bucket', 'Planned', 'Spent', 'Difference'], flexes),
      for (final line in statement.bucketLines)
        _tableRow(
          [
            line.bucket.name,
            line.plannedMinor == 0
                ? '-'
                : formatMoney(line.plannedMinor, currency: currency),
            formatMoney(line.actualMinor, currency: currency),
            line.plannedMinor == 0
                ? '-'
                : _signed(-line.varianceMinor, currency),
          ],
          flexes,
          // Spend is inverted before display: under plan is the good outcome,
          // so a negative variance must print green, not red.
          lastCellColor: line.plannedMinor == 0
              ? _muted
              : (line.varianceMinor > 0 ? _terracotta : _green),
        ),
      pw.SizedBox(height: 6),
      _tableRow(
        [
          'Total',
          formatMoney(statement.report.spend.plannedMinor, currency: currency),
          formatMoney(statement.report.spend.actualMinor, currency: currency),
          _signed(-statement.report.spend.varianceMinor, currency),
        ],
        flexes,
        lastCellColor:
            statement.report.spend.varianceMinor > 0 ? _terracotta : _green,
      ),
    ],
  );
}

pw.Widget _transactionTable(MonthlyStatement statement) {
  final currency = statement.currency;
  const flexes = [3, 5, 4, 3];

  return pw.Column(
    children: [
      _tableHeader(const ['Date', 'Payee', 'Bucket', 'Amount'], flexes),
      for (final expense in statement.expensesInDateOrder)
        _tableRow(
          [
            formatDate(expense.occurredOn),
            expense.payee ?? '-',
            statement.bucketName(expense.bucketId),
            formatMoney(expense.amountMinor, currency: currency),
          ],
          flexes,
        ),
    ],
  );
}

String _signed(int amountMinor, String currency) {
  final formatted = formatMoney(amountMinor.abs(), currency: currency);
  if (amountMinor == 0) return formatted;
  return amountMinor > 0 ? '+$formatted' : '-$formatted';
}

