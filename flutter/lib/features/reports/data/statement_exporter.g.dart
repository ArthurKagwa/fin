// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statement_exporter.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(statementExporter)
final statementExporterProvider = StatementExporterProvider._();

final class StatementExporterProvider
    extends
        $FunctionalProvider<
          StatementExporter,
          StatementExporter,
          StatementExporter
        >
    with $Provider<StatementExporter> {
  StatementExporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'statementExporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$statementExporterHash();

  @$internal
  @override
  $ProviderElement<StatementExporter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StatementExporter create(Ref ref) {
    return statementExporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StatementExporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StatementExporter>(value),
    );
  }
}

String _$statementExporterHash() => r'258951701a21f38ebdf2ac35482d60a61bae2f3f';
