import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/planning/application/plan_vs_actual.dart';
import 'package:fintrack/features/planning/presentation/widgets/bullet_bar.dart';
import 'package:fintrack/features/planning/presentation/widgets/variance_style.dart';
import 'package:flutter/material.dart';

/// One labelled planned-vs-actual line: name, the two amounts, the bar, and a
/// one-word verdict.
///
/// Used unchanged for the two summary lines, for each expected income source
/// and for each bucket, so the whole feature reads as a single system rather
/// than three screens that happen to share a colour palette.
class VarianceRow extends StatelessWidget {
  const VarianceRow({
    super.key,
    required this.line,
    required this.currency,
    this.showPaceMarker = true,
    this.onTap,
  });

  final VarianceLine line;
  final String currency;
  final bool showPaceMarker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final style = varianceStyleFor(context, line, currency: currency);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(line.label, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(width: 12),
            Text(
              formatMoney(line.actualMinor, currency: currency),
              style: theme.textTheme.titleMedium,
            ),
            if (line.hasPlan)
              Text(
                ' of ${formatMoney(line.plannedMinor, currency: currency)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        BulletBar(
          plannedMinor: line.plannedMinor,
          actualMinor: line.actualMinor,
          fillColor: style.color,
          paceMarker: showPaceMarker ? line.monthProgress : null,
          semanticLabel: varianceSemanticLabel(line, currency: currency),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(style.icon, size: 14, color: style.color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                style.label,
                style: theme.textTheme.labelMedium?.copyWith(color: style.color),
              ),
            ),
          ],
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.all(4), child: content),
    );
  }
}
