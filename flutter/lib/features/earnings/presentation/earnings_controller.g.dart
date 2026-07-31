// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earnings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A different reading of the income records the app already keeps, not a
/// second source of truth. Exposed as a stream rather than derived from
/// [incomeEventsProvider]'s `AsyncValue` so the screen keeps real loading and
/// error branches instead of silently rendering an empty report.

@ProviderFor(earningsSummary)
final earningsSummaryProvider = EarningsSummaryProvider._();

/// A different reading of the income records the app already keeps, not a
/// second source of truth. Exposed as a stream rather than derived from
/// [incomeEventsProvider]'s `AsyncValue` so the screen keeps real loading and
/// error branches instead of silently rendering an empty report.

final class EarningsSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<EarningsSummary>,
          EarningsSummary,
          Stream<EarningsSummary>
        >
    with $FutureModifier<EarningsSummary>, $StreamProvider<EarningsSummary> {
  /// A different reading of the income records the app already keeps, not a
  /// second source of truth. Exposed as a stream rather than derived from
  /// [incomeEventsProvider]'s `AsyncValue` so the screen keeps real loading and
  /// error branches instead of silently rendering an empty report.
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

String _$earningsSummaryHash() => r'f5efbefac1e5be5576d336d14066ebcd44e525e7';
