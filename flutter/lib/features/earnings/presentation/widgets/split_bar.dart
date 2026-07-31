import 'package:flutter/material.dart';

/// A parts-of-a-whole bar: take-home over deductions, together making gross.
///
/// Deliberately not the planning feature's `BulletBar`. That one answers "how
/// far through a target am I?"; this one answers "how was this amount split?".
/// Reusing one shape for both meanings would teach the wrong reading rule.
class SplitBar extends StatelessWidget {
  const SplitBar({
    super.key,
    required this.primaryMinor,
    required this.secondaryMinor,
    required this.primaryColor,
    required this.secondaryColor,
    this.height = 8,
    this.semanticLabel,
  });

  final int primaryMinor;
  final int secondaryMinor;
  final Color primaryColor;
  final Color secondaryColor;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = primaryMinor + secondaryMinor;
    final primaryFraction =
        total > 0 ? (primaryMinor / total).clamp(0.0, 1.0) : 0.0;

    // Drawn as a fraction over a full-width track rather than two flexed
    // children: a `flex: 0` child in a Row lays out unconstrained, which is
    // exactly what happens in the all-deductions or all-take-home cases.
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: total > 0 ? secondaryColor : colorScheme.surfaceContainerHigh,
            ),
            if (primaryFraction > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: primaryFraction,
                  heightFactor: 1,
                  child: ColoredBox(color: primaryColor),
                ),
              ),
          ],
        ),
      ),
    );

    if (semanticLabel == null) return bar;
    return Semantics(label: semanticLabel, container: true, child: bar);
  }
}
