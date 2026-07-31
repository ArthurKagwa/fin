import 'package:fintrack/core/utils/money.dart';
import 'package:flutter/material.dart';

/// A tappable date pill used on the entry sheets.
///
/// Shared rather than copied so the tap target stays honest: it sits on the
/// fastest path in the app and was previously about 30dp tall, under the 48dp
/// minimum.
class DateChip extends StatelessWidget {
  const DateChip({
    super.key,
    required this.date,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.semanticsLabel = 'Change date',
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Semantics(
      button: true,
      label: '$semanticsLabel, currently ${formatDate(date)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: firstDate ?? now.subtract(const Duration(days: 365 * 3)),
            lastDate: lastDate ?? now.add(const Duration(days: 1)),
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                relativeDate(date),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
