import 'package:fintrack/core/utils/money.dart';
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
            onPressed: () => _showCreateDialog(context, ref),
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
                      onPressed: () => _showCreateDialog(context, ref),
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
                  trailing: IconButton(
                    icon: const Icon(Icons.archive_outlined),
                    onPressed: () => ref.read(bucketControllerProvider.notifier).archive(bucket.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final plannedController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New bucket'),
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
              ref.read(bucketControllerProvider.notifier).create(
                    name: name,
                    plannedMinor: planned,
                  );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
