import 'package:fintrack/features/buckets/application/bucket.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/buckets/presentation/bucket_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BucketFormScreen extends ConsumerStatefulWidget {
  const BucketFormScreen({super.key, this.bucketId});

  final String? bucketId;

  bool get isEditing => bucketId != null;

  @override
  ConsumerState<BucketFormScreen> createState() => _BucketFormScreenState();
}

class _BucketFormScreenState extends ConsumerState<BucketFormScreen> {
  final _nameController = TextEditingController();
  final _plannedController = TextEditingController();
  final _goalController = TextEditingController();
  bool _prefilled = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _plannedController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _prefill(Bucket bucket) {
    if (_prefilled) return;
    _prefilled = true;
    _nameController.text = bucket.name;
    _plannedController.text = bucket.plannedMinor?.toString() ?? '';
    _goalController.text = bucket.goalMinor?.toString() ?? '';
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    final planned = int.tryParse(_plannedController.text.replaceAll(',', ''));
    final goal = int.tryParse(_goalController.text.replaceAll(',', ''));
    final controller = ref.read(bucketControllerProvider.notifier);

    if (widget.isEditing) {
      await controller.update(
        id: widget.bucketId!,
        name: name,
        plannedMinor: planned,
        goalMinor: goal,
      );
    } else {
      await controller.create(name: name, plannedMinor: planned, goalMinor: goal);
    }

    if (!mounted) return;
    if (ref.read(bucketControllerProvider).hasError) {
      setState(() => _error = 'Could not save. Try again.');
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSaving = ref.watch(bucketControllerProvider).isLoading;

    Widget buildForm() {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          TextField(
            controller: _nameController,
            autofocus: !widget.isEditing,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _plannedController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Planned amount (optional)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _goalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Goal amount (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isSaving ? null : _submit,
            child: isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEditing ? 'Save' : 'Create'),
          ),
        ],
      );
    }

    if (!widget.isEditing) {
      return Scaffold(
        appBar: AppBar(title: const Text('New bucket')),
        body: buildForm(),
      );
    }

    final bucketsAsync = ref.watch(activeBucketsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit bucket')),
      body: bucketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load bucket: $error')),
        data: (buckets) {
          Bucket? bucket;
          for (final candidate in buckets) {
            if (candidate.id == widget.bucketId) {
              bucket = candidate;
              break;
            }
          }
          if (bucket == null) {
            return const Center(child: Text('Bucket not found.'));
          }
          _prefill(bucket);
          return buildForm();
        },
      ),
    );
  }
}
