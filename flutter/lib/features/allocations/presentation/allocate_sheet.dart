import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/core/widgets/money_field.dart';
import 'package:fintrack/features/allocations/presentation/allocation_controller.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Assigns money out of the unallocated pool into one or more buckets.
///
/// Opened from an income entry for context (the sheet says where the money
/// came from), but the amount available to give away is the *global*
/// unallocated pool, not just this entry's own contribution — once income
/// lands it's fungible, same as every other envelope-budgeting app's
/// "ready to assign" figure.
class AllocateSheet extends ConsumerStatefulWidget {
  const AllocateSheet({super.key, required this.source});

  final IncomeEvent source;

  @override
  ConsumerState<AllocateSheet> createState() => _AllocateSheetState();
}

class _AllocateSheetState extends ConsumerState<AllocateSheet> {
  final Map<String, TextEditingController> _controllers = {};
  String? _error;

  TextEditingController _controllerFor(String bucketId) =>
      _controllers.putIfAbsent(bucketId, () => TextEditingController());

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _enteredTotal =>
      _controllers.values.fold(0, (sum, c) => sum + moneyFromField(c));

  Future<void> _save(int unallocated) async {
    final entries = _controllers.entries
        .where((entry) => moneyFromField(entry.value) > 0)
        .toList();
    if (entries.isEmpty) {
      setState(() => _error = 'Enter an amount for at least one bucket.');
      return;
    }
    if (_enteredTotal > unallocated) {
      setState(() => _error = 'That\'s more than you have unallocated.');
      return;
    }

    final controller = ref.read(allocationControllerProvider.notifier);
    for (final entry in entries) {
      await controller.allocate(
        incomeEventId: widget.source.id,
        bucketId: entry.key,
        amountMinor: moneyFromField(entry.value),
      );
      if (ref.read(allocationControllerProvider).hasError) {
        if (!mounted) return;
        setState(() => _error = 'Could not save. Try again.');
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyCodeProvider);
    final unallocated = ref.watch(unallocatedMinorProvider);
    final bucketsAsync = ref.watch(activeBucketsProvider);
    final isSaving = ref.watch(allocationControllerProvider).isLoading;
    final remaining = unallocated - _enteredTotal;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Allocate money in', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'From ${widget.source.source}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Remaining to allocate', style: theme.textTheme.bodyMedium),
                  Text(
                    formatMoney(remaining, currency: currency),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: remaining < 0 ? theme.colorScheme.error : theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            bucketsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Could not load buckets: $error'),
              data: (buckets) {
                if (buckets.isEmpty) {
                  return Text(
                    'Create a bucket first to allocate money into it.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final bucket in buckets) ...[
                      MoneyField(
                        controller: _controllerFor(bucket.id),
                        currency: currency,
                        label: bucket.name,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isSaving ? null : () => _save(unallocated),
              child: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
