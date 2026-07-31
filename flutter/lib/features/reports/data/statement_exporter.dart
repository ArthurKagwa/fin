import 'dart:typed_data';

import 'package:fintrack/core/errors/app_failure.dart';
import 'package:fintrack/features/reports/application/monthly_statement.dart';
import 'package:fintrack/features/reports/data/statement_pdf.dart';
import 'package:printing/printing.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'statement_exporter.g.dart';

abstract class StatementExporter {
  /// Renders [statement] and hands it to the platform share sheet. Resolves to
  /// false when the user dismisses the sheet without choosing a destination.
  Future<bool> share(MonthlyStatement statement);

  /// Renders without sharing — used by tests and by the preview.
  Future<Uint8List> render(MonthlyStatement statement);
}

class PrintingStatementExporter implements StatementExporter {
  const PrintingStatementExporter();

  @override
  Future<Uint8List> render(MonthlyStatement statement) =>
      buildStatementPdf(statement);

  @override
  Future<bool> share(MonthlyStatement statement) async {
    try {
      final bytes = await buildStatementPdf(statement);
      return await Printing.sharePdf(
        bytes: bytes,
        filename: statement.fileName,
      );
    } on Exception catch (error) {
      throw ExportFailure('Could not build the statement: $error');
    }
  }
}

@Riverpod(keepAlive: true)
StatementExporter statementExporter(Ref ref) =>
    const PrintingStatementExporter();
