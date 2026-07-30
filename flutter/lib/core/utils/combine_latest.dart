import 'dart:async';

Stream<T> combineLatest2<A, B, T>(
  Stream<A> streamA,
  Stream<B> streamB,
  T Function(A, B) combiner,
) {
  late StreamController<T> controller;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  void emit() {
    if (hasA && hasB) {
      controller.add(combiner(latestA as A, latestB as B));
    }
  }

  controller = StreamController<T>.broadcast(
    onListen: () {
      subA = streamA.listen(
        (a) {
          latestA = a;
          hasA = true;
          emit();
        },
        onError: controller.addError,
      );
      subB = streamB.listen(
        (b) {
          latestB = b;
          hasB = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}
