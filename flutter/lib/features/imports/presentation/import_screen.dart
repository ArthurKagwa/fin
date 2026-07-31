import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fintrack/core/utils/money.dart';
import 'package:fintrack/features/buckets/data/bucket_repository.dart';
import 'package:fintrack/features/expenses/data/expense_repository.dart';
import 'package:fintrack/features/expenses/presentation/expense_controller.dart';
import 'package:fintrack/features/imports/application/import_row.dart';
import 'package:fintrack/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _Step { pickFile, mapColumns, preview, done }

/// CSV transaction import: pick a file, map its columns to date/amount/payee,
/// preview the parsed rows (duplicates flagged, not excluded, per FR-14),
/// pick which bucket they land in, commit.
///
/// One bucket for the whole import, not a per-row picker — matching a CSV's
/// free-text category column to this app's buckets would need fuzzy
/// matching that's a separate feature, not a prerequisite for "get my
/// history in at all."
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _Step _step = _Step.pickFile;
  String? _error;
  bool _busy = false;

  List<List<dynamic>> _table = [];
  bool _hasHeader = true;
  int? _dateColumn;
  int? _amountColumn;
  int? _payeeColumn;

  List<ImportRow> _rows = [];
  String? _bucketId;
  int _importedCount = 0;

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      final bytes = result?.files.single.bytes;
      if (bytes == null) {
        setState(() => _busy = false);
        return;
      }
      final content = utf8.decode(bytes, allowMalformed: true);
      final table = csv.decode(content);
      if (table.isEmpty) {
        setState(() {
          _error = 'That file has no rows.';
          _busy = false;
        });
        return;
      }
      setState(() {
        _table = table;
        _dateColumn = 0;
        _amountColumn = table.first.length > 1 ? 1 : 0;
        _step = _Step.mapColumns;
        _busy = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not read that file. Make sure it\'s a CSV.';
        _busy = false;
      });
    }
  }

  Future<void> _buildPreview() async {
    if (_dateColumn == null || _amountColumn == null) return;
    setState(() => _busy = true);
    final currency = ref.read(currencyCodeProvider);
    final existing = await ref.read(expenseRepositoryProvider).watchExpenses().first;
    final rows = buildImportRows(
      table: _table,
      dateColumn: _dateColumn!,
      amountColumn: _amountColumn!,
      payeeColumn: _payeeColumn,
      hasHeader: _hasHeader,
      currency: currency,
      existing: existing,
    );
    final buckets = ref.read(activeBucketsProvider).asData?.value ?? const [];
    setState(() {
      _rows = rows;
      _bucketId = buckets.isEmpty ? null : buckets.first.id;
      _step = _Step.preview;
      _busy = false;
    });
  }

  Future<void> _commit() async {
    if (_bucketId == null || _rows.isEmpty) return;
    setState(() {
      _busy = true;
      _importedCount = 0;
    });
    final controller = ref.read(expenseControllerProvider.notifier);
    for (final row in _rows) {
      await controller.addExpense(
        bucketId: _bucketId!,
        amountMinor: row.amountMinor,
        occurredOn: row.occurredOn,
        payee: row.payee,
      );
      if (!mounted) return;
      setState(() => _importedCount++);
    }
    setState(() {
      _busy = false;
      _step = _Step.done;
    });
  }

  String _columnLabel(int index) {
    if (_hasHeader && _table.isNotEmpty && index < _table.first.length) {
      final header = _table.first[index].toString().trim();
      if (header.isNotEmpty) return header;
    }
    return 'Column ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: switch (_step) {
        _Step.pickFile => _buildPickFile(),
        _Step.mapColumns => _buildMapColumns(),
        _Step.preview => _buildPreview_(),
        _Step.done => _buildDone(),
      },
    );
  }

  Widget _buildPickFile() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text('Bring in past transactions', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Pick a CSV export from your bank or spreadsheet. You\'ll map its '
              'columns and preview everything before it\'s saved.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: _busy
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.folder_open),
              label: const Text('Choose file'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapColumns() {
    final theme = Theme.of(context);
    final columnCount = _table.isEmpty ? 0 : _table.first.length;
    final columns = List.generate(columnCount, (i) => i);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('First row is a header'),
          value: _hasHeader,
          onChanged: (value) => setState(() => _hasHeader = value),
        ),
        const SizedBox(height: 12),
        Text('Which column is which?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _dateColumn,
          decoration: const InputDecoration(labelText: 'Date'),
          items: [for (final c in columns) DropdownMenuItem(value: c, child: Text(_columnLabel(c)))],
          onChanged: (value) => setState(() => _dateColumn = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _amountColumn,
          decoration: const InputDecoration(labelText: 'Amount'),
          items: [for (final c in columns) DropdownMenuItem(value: c, child: Text(_columnLabel(c)))],
          onChanged: (value) => setState(() => _amountColumn = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          initialValue: _payeeColumn,
          decoration: const InputDecoration(labelText: 'Payee / description (optional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final c in columns) DropdownMenuItem(value: c, child: Text(_columnLabel(c))),
          ],
          onChanged: (value) => setState(() => _payeeColumn = value),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy || _dateColumn == null || _amountColumn == null ? null : _buildPreview,
          child: _busy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Preview'),
        ),
      ],
    );
  }

  Widget _buildPreview_() {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyCodeProvider);
    final bucketsAsync = ref.watch(activeBucketsProvider);
    final duplicateCount = _rows.where((r) => r.isDuplicate).length;

    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No valid rows found with those column choices — go back and try different columns.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_rows.length} rows found'
                  '${duplicateCount > 0 ? ' · $duplicateCount possible duplicates' : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: bucketsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Could not load buckets: $error'),
            data: (buckets) {
              if (buckets.isEmpty) {
                return const Text('Create a bucket first to import into it.');
              }
              return DropdownButtonFormField<String>(
                initialValue: _bucketId,
                decoration: const InputDecoration(labelText: 'Import into'),
                items: [for (final b in buckets) DropdownMenuItem(value: b.id, child: Text(b.name))],
                onChanged: (value) => setState(() => _bucketId = value),
              );
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final row = _rows[index];
              return ListTile(
                dense: true,
                title: Text(row.payee ?? '(no payee)'),
                subtitle: Text(formatDate(row.occurredOn)),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatMoney(row.amountMinor, currency: currency)),
                    if (row.isDuplicate)
                      Text(
                        'Possible duplicate',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: FilledButton(
            onPressed: _busy || _bucketId == null ? null : _commit,
            child: _busy
                ? Text('Importing $_importedCount / ${_rows.length}...')
                : Text('Import ${_rows.length} transactions'),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 56, color: theme.colorScheme.secondary),
            const SizedBox(height: 20),
            Text('Imported $_importedCount transactions', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
