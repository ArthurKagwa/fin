import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:fintrack/features/planning/presentation/widgets/variance_row.dart';
import 'package:flutter/material.dart';

/// The month in one block: a single headline number, the sentence that explains
/// it, and the two bars behind it.
///
/// Leads with one number rather than four. Planned-in, actual-in, planned-out
/// and actual-out don't compose in a reader's head; "left to spend" does, and
/// the four raw figures stay available one level down.
class PlanSummary extends StatelessWidget {
  const PlanSummary({
    super.key,
    required this.report,
    required this.currency,
  });

  final PlanVsActual report;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOverspent = report.leftToSpendMinor < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOverspent ? 'Over your plan by' : 'Left to spend',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(
                      report.leftToSpendMinor.abs(),
                      currency: currency,
                    ),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: isOverspent ? colorScheme.error : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                report.isCurrentMonth
                    ? 'Day ${report.daysElapsed} of ${report.daysInMonth}'
                    : '${report.daysInMonth} days',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _headline(report, currency),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        VarianceRow(line: report.income, currency: currency),
        const SizedBox(height: 18),
        VarianceRow(line: report.spend, currency: currency),
        if (report.plannedOverspendMinor > 0) ...[
          const SizedBox(height: 16),
          _PlanWarning(
            message:
                'Your plan spends ${formatMoney(report.plannedOverspendMinor, currency: currency)} '
                'more than you expect to earn.',
          ),
        ],
        if (!report.plan.isSnapshot && !report.isCurrentMonth) ...[
          const SizedBox(height: 12),
          Text(
            'No plan was recorded for this month — shown against your current '
            'bucket amounts.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// The one sentence that turns the headline number into a decision. Projection
/// only appears once enough of the month has passed for it to mean anything —
/// extrapolating from two days produces confident nonsense.
String _headline(PlanVsActual report, String currency) {
  if (!report.hasPlan) {
    return 'No plan set for this month yet.';
  }
  if (!report.isCurrentMonth) {
    final variance = report.spend.varianceMinor;
    if (variance > 0) {
      return 'Finished ${formatMoney(variance, currency: currency)} over plan.';
    }
    return 'Finished ${formatMoney(-variance, currency: currency)} under plan.';
  }

  final buffer = StringBuffer('${report.daysRemaining} days left');
  if (report.monthProgress >= 0.25 && report.spend.hasPlan) {
    final projected = report.projectedSpendMinor;
    final gap = projected - report.spend.plannedMinor;
    if (gap > 0) {
      buffer.write(
        ' · at this rate you finish ${formatMoney(gap, currency: currency)} over',
      );
    } else {
      buffer.write(
        ' · at this rate you finish ${formatMoney(-gap, currency: currency)} under',
      );
    }
  }
  return buffer.toString();
}

class _PlanWarning extends StatelessWidget {
  const _PlanWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
