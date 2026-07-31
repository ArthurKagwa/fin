import 'package:fintrack/features/reports/application/monthly_statement.dart';
import 'package:fintrack/features/reports/data/statement_exporter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'export_controller.g.dart';

@riverpod
class ExportController extends _$ExportController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Renders and shares the statement. Dismissing the share sheet is a normal
  /// outcome, not an error — it resolves to data, so the screen shows nothing.
  Future<void> shareStatement(MonthlyStatement statement) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(statementExporterProvider).share(statement),
    );
  }
}
