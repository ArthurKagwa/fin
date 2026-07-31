import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/buckets/presentation/bucket_controller.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BucketDetailScreen extends ConsumerWidget {
  const BucketDetailScreen({super.key, required this.bucketId});

  final String bucketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // All buckets, not just active ones — an archived bucket must stay
    // reachable here (to view it or to unarchive it) rather than vanishing
    // the moment it's archived.
    final bucketsAsync = ref.watch(allBucketsProvider);
    final currency = ref.watch(currencyCodeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bucket')),
      body: bucketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load bucket: $error')),
        data: (buckets) {
          Bucket? bucket;
          for (final candidate in buckets) {
            if (candidate.id == bucketId) {
              bucket = candidate;
              break;
            }
          }
          if (bucket == null) {
            return const Center(child: Text('Bucket not found.'));
          }
          return _BucketDetailBody(bucket: bucket, currency: currency);
        },
      ),
    );
  }
}

class _BucketDetailBody extends ConsumerWidget {
  const _BucketDetailBody({required this.bucket, required this.currency});

  final Bucket bucket;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(bucket.name, style: Theme.of(context).textTheme.headlineSmall),
            ),
            if (bucket.isArchived)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Archived',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  label: 'Balance',
                  value: formatMoney(bucket.balanceMinor, currency: currency),
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Planned amount',
                  value: formatMoney(bucket.plannedMinor ?? 0, currency: currency),
                ),
                if (bucket.goalMinor != null) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Goal',
                    value: formatMoney(bucket.goalMinor!, currency: currency),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (bucket.isArchived) ...[
          FilledButton.icon(
            onPressed: () => ref.read(bucketControllerProvider.notifier).unarchive(bucket.id),
            icon: const Icon(Icons.unarchive_outlined),
            label: const Text('Unarchive'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: () => context.push('/buckets/${bucket.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => _handleDeleteTap(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ],
    );
  }

  Future<void> _handleDeleteTap(BuildContext context, WidgetRef ref) async {
    final hasRefs = await ref.read(bucketControllerProvider.notifier).hasReferences(bucket.id);
    if (!context.mounted) return;
    if (hasRefs) {
      _confirmArchive(context, ref);
    } else {
      _confirmHardDelete(context, ref);
    }
  }

  void _confirmArchive(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive bucket?'),
        content: Text(
          '"${bucket.name}" has expenses or recurring payments logged against it, '
          'so it can\'t be deleted outright without losing that history. '
          'Archiving hides it from new entries — you can unarchive it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(bucketControllerProvider.notifier).archive(bucket.id);
              if (context.mounted) context.pop();
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _confirmHardDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete bucket?'),
        content: Text('This removes "${bucket.name}" completely. It has no history yet, so nothing else is affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(bucketControllerProvider.notifier).delete(bucket.id);
              if (context.mounted) context.pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
