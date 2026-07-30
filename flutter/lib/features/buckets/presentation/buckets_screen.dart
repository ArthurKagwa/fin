import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/buckets/presentation/bucket_controller.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BucketsScreen extends ConsumerWidget {
  const BucketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucketsAsync = ref.watch(activeBucketsProvider);
    final currency = ref.watch(currencyCodeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Buckets', style: Theme.of(context).textTheme.headlineMedium),
        actions: [
          IconButton(
            onPressed: () => _showBucketDialog(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: bucketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load buckets: $error')),
        data: (buckets) {
          if (buckets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No buckets yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a bucket to start planning your spending.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => _showBucketDialog(context, ref),
                      child: const Text('Create a bucket'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: buckets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final bucket = buckets[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryFixed,
                    foregroundColor: colorScheme.primary,
                    child: Text(bucket.name.substring(0, 1)),
                  ),
                  title: Text(bucket.name, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(
                    bucket.goalMinor != null
                        ? 'Planned ${formatMoney(bucket.plannedMinor ?? 0, symbol: currency)} · Goal ${formatMoney(bucket.goalMinor!, symbol: currency)}'
                        : 'Planned ${formatMoney(bucket.plannedMinor ?? 0, symbol: currency)}',
                  ),
                  trailing: PopupMenuButton<_BucketAction>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      if (action == _BucketAction.edit) {
                        _showBucketDialog(context, ref, existing: bucket);
                      } else {
                        _confirmDelete(context, ref, bucket);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _BucketAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _BucketAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showBucketDialog(BuildContext context, WidgetRef ref, {Bucket? existing}) {
    final isEditing = existing != null;
    final nameController = TextEditingController(text: existing?.name);
    final plannedController = TextEditingController(
      text: existing?.plannedMinor?.toString(),
    );
    final goalController = TextEditingController(
      text: existing?.goalMinor?.toString(),
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEditing ? 'Edit bucket' : 'New bucket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: plannedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Planned amount (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Goal amount (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final planned = int.tryParse(plannedController.text.replaceAll(',', ''));
              final goal = int.tryParse(goalController.text.replaceAll(',', ''));
              if (isEditing) {
                ref.read(bucketControllerProvider.notifier).update(
                      id: existing.id,
                      name: name,
                      plannedMinor: planned,
                      goalMinor: goal,
                    );
              } else {
                ref.read(bucketControllerProvider.notifier).create(
                      name: name,
                      plannedMinor: planned,
                      goalMinor: goal,
                    );
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text(isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Bucket bucket) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete bucket?'),
        content: Text(
          'This removes "${bucket.name}". Expenses already logged against it are kept but will '
          'no longer be tracked in this bucket.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(bucketControllerProvider.notifier).delete(bucket.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

enum _BucketAction { edit, delete }
