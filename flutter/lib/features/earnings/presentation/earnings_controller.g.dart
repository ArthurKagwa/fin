// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earnings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(earningsSummary)
final earningsSummaryProvider = EarningsSummaryProvider._();

final class EarningsSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<EarningsSummary>,
          EarningsSummary,
          Stream<EarningsSummary>
        >
    with $FutureModifier<EarningsSummary>, $StreamProvider<EarningsSummary> {
  EarningsSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'earningsSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$earningsSummaryHash();

  @$internal
  @override
  $StreamProviderElement<EarningsSummary> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<EarningsSummary> create(Ref ref) {
    return earningsSummary(ref);
  }
}

String _$earningsSummaryHash() => r'3f81b6c2a074e935db218c4f60a37e5b91c48d02';
