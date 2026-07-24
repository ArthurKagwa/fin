import 'package:fintrack/features/dashboard/application/dashboard_summary.dart';

abstract class DashboardRepository {
  Future<DashboardSummary> getDashboardSummary({DateTime? month});
}

class FirestoreDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSummary> getDashboardSummary({DateTime? month}) {
    throw UnimplementedError('getDashboardSummary');
  }
}
