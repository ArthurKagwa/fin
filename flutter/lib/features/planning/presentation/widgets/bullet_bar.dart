import 'package:flutter/material.dart';

/// A planned-vs-actual bar: a light track for the plan, a filled bar for the
/// actual, and a tick marking where the month's pace says you should be.
///
/// This is the one visual idiom the whole feature leans on. The reading rule —
/// *bar past the tick means ahead of plan* — is learned once on the dashboard
/// card and then applies unchanged to every bucket row and every income source,
/// which is why this widget is shared rather than reimplemented per screen.
class BulletBar extends StatelessWidget {
  const BulletBar({
    super.key,
    required this.plannedMinor,
    required this.actualMinor,
    required this.fillColor,
    this.paceMarker,
    this.height = 8,
    this.semanticLabel,
  });

  final int plannedMinor;
  final int actualMinor;
  final Color fillColor;

  /// Fraction of the month elapsed, 0..1. Null hides the tick — used where
  /// pace is meaningless, such as a month that has already ended.
  final double? paceMarker;

  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPlan = plannedMinor > 0;
    final ratio = hasPlan ? actualMinor / plannedMinor : 0.0;
    final isOverflowing = ratio > 1;
    final fillFraction = ratio.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height / 2);

    final bar = SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: radius,
            ),
          ),
          if (fillFraction > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fillFraction,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isOverflowing ? colorScheme.error : fillColor,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          // Overspend must never read as a neatly full bar — the cap shows the
          // bar has burst past the plan rather than just reached it.
          if (isOverflowing)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: height * 0.75,
                margin: EdgeInsets.only(left: height * 0.25),
                decoration: BoxDecoration(
                  color: colorScheme.onErrorContainer,
                  borderRadius: radius,
                  border: Border.all(color: colorScheme.surface, width: 1.5),
                ),
              ),
            ),
          if (paceMarker != null)
            Align(
              alignment: Alignment(paceMarker!.clamp(0.0, 1.0) * 2 - 1, 0),
              child: Container(
                width: 2,
                height: height,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
        ],
      ),
    );

    if (semanticLabel == null) return bar;
    // Colour alone never carries the meaning — the label restates the numbers
    // and the pace for anyone who can't see the bar.
    return Semantics(label: semanticLabel, container: true, child: bar);
  }
}
