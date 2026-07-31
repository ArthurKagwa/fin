import 'package:fintrack/core/theme/app_theme.dart';
import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:flutter/material.dart';

/// Colour, icon and wording for one variance line.
///
/// Centralised because the same [VarianceLine] must read identically on the
/// dashboard card, the bucket cards and the report — and because the sign
/// convention is easy to get backwards: being under plan is good on spend and
/// bad on income. Resolving it in one place means no widget can disagree.
class VarianceStyle {
  const VarianceStyle({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;
}

VarianceStyle varianceStyleFor(
  BuildContext context,
  VarianceLine line, {
  required String currency,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  if (!line.hasPlan) {
    return VarianceStyle(
      color: colorScheme.onSurfaceVariant,
      icon: Icons.remove_circle_outline,
      label: 'Not planned',
    );
  }

  if (line.higherIsBetter) {
    // Income. Falling short mid-month is normal, so the only real signal is
    // pace; exceeding the plan is simply good news.
    if (line.actualMinor >= line.plannedMinor) {
      final over = line.varianceMinor;
      return VarianceStyle(
        color: colorScheme.secondary,
        icon: Icons.check_circle_outline,
        label: over > 0
            ? '${formatMoney(over, symbol: currency)} above plan'
            : 'All in',
      );
    }
    final short = -line.varianceMinor;
    return switch (line.state) {
      VarianceState.offPace || VarianceState.offPlan => VarianceStyle(
          color: AppColors.caution,
          icon: Icons.schedule,
          label: '${formatMoney(short, symbol: currency)} still to come',
        ),
      VarianceState.onTrack => VarianceStyle(
          color: colorScheme.secondary,
          icon: Icons.check_circle_outline,
          label: 'On track',
        ),
    };
  }

  // Spend.
  return switch (line.state) {
    VarianceState.offPlan => VarianceStyle(
        color: colorScheme.error,
        icon: Icons.error_outline,
        label: 'Over plan by ${formatMoney(line.varianceMinor, symbol: currency)}',
      ),
    VarianceState.offPace => VarianceStyle(
        color: AppColors.caution,
        icon: Icons.trending_up,
        label: 'Ahead of pace',
      ),
    VarianceState.onTrack => VarianceStyle(
        color: colorScheme.secondary,
        icon: Icons.check_circle_outline,
        label: 'On track',
      ),
  };
}

/// Screen-reader description of a bar: the numbers and the pace, so the bar's
/// meaning survives without colour or shape.
String varianceSemanticLabel(VarianceLine line, {required String currency}) {
  final actual = formatMoney(line.actualMinor, symbol: currency);
  if (!line.hasPlan) return '$actual, nothing planned';
  final planned = formatMoney(line.plannedMinor, symbol: currency);
  final percentElapsed = (line.monthProgress * 100).round();
  return '$actual of $planned planned, $percentElapsed% of the month elapsed';
}
