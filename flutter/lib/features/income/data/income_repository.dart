import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fintrack/core/providers/firebase_providers.dart';
import 'package:fintrack/features/auth/data/auth_repository.dart';
import 'package:fintrack/features/income/application/income_event.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'income_repository.g.dart';

abstract class IncomeRepository {
  Stream<List<IncomeEvent>> watchIncomeEvents();
  Future<IncomeEvent> addIncomeEvent({
    required IncomeKind kind,
    required int amountMinor,
    required DateTime occurredOn,
    required String source,
    int? grossMinor,
    String? note,
    List<({String label, int amountMinor})> deductions = const [],
  });
}

class FirestoreIncomeRepository implements IncomeRepository {
  FirestoreIncomeRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('incomeEvents');

  @override
  Stream<List<IncomeEvent>> watchIncomeEvents() {
    return _collection.orderBy('occurredOn', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }

  @override
  Future<IncomeEvent> addIncomeEvent({
    required IncomeKind kind,
    required int amountMinor,
    required DateTime occurredOn,
    required String source,
    int? grossMinor,
    String? note,
    List<({String label, int amountMinor})> deductions = const [],
  }) async {
    final doc = await _collection.add({
      'kind': kind.name,
      'amountMinor': amountMinor,
      'occurredOn': Timestamp.fromDate(occurredOn),
      'source': source,
      'grossMinor': grossMinor,
      'note': note,
      'deductions': [
        for (var i = 0; i < deductions.length; i++)
          {
            'id': '$i',
            'label': deductions[i].label,
            'amountMinor': deductions[i].amountMinor,
            'sortOrder': i,
          },
      ],
    });
    final snapshot = await doc.get();
    return _fromDoc(snapshot);
  }

  IncomeEvent _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final deductions = (data['deductions'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(
          (d) => Deduction(
            id: d['id'] as String,
            label: d['label'] as String,
            amountMinor: d['amountMinor'] as int,
            sortOrder: d['sortOrder'] as int,
          ),
        )
        .toList();
    return IncomeEvent(
      id: doc.id,
      kind: IncomeKind.values.byName(data['kind'] as String),
      amountMinor: data['amountMinor'] as int,
      occurredOn: (data['occurredOn'] as Timestamp).toDate(),
      source: data['source'] as String,
      grossMinor: data['grossMinor'] as int?,
      note: data['note'] as String?,
      deductions: deductions,
    );
  }
}

@Riverpod(keepAlive: true)
IncomeRepository incomeRepository(Ref ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('incomeRepository read while signed out');
  return FirestoreIncomeRepository(ref.watch(firebaseFirestoreProvider), uid);
}

@Riverpod(keepAlive: true)
Stream<List<IncomeEvent>> incomeEvents(Ref ref) =>
    ref.watch(incomeRepositoryProvider).watchIncomeEvents();
