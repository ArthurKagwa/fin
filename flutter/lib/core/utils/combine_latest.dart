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

Stream<T> combineLatest3<A, B, C, T>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  T Function(A, B, C) combiner,
) {
  late StreamController<T> controller;
  A? latestA;
  B? latestB;
  C? latestC;
  var hasA = false;
  var hasB = false;
  var hasC = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;

  void emit() {
    if (hasA && hasB && hasC) {
      controller.add(combiner(latestA as A, latestB as B, latestC as C));
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
      subC = streamC.listen(
        (c) {
          latestC = c;
          hasC = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
    },
  );
  return controller.stream;
}

Stream<T> combineLatest4<A, B, C, D, T>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  Stream<D> streamD,
  T Function(A, B, C, D) combiner,
) {
  late StreamController<T> controller;
  A? latestA;
  B? latestB;
  C? latestC;
  D? latestD;
  var hasA = false;
  var hasB = false;
  var hasC = false;
  var hasD = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;
  StreamSubscription<D>? subD;

  void emit() {
    if (hasA && hasB && hasC && hasD) {
      controller.add(
        combiner(latestA as A, latestB as B, latestC as C, latestD as D),
      );
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
      subC = streamC.listen(
        (c) {
          latestC = c;
          hasC = true;
          emit();
        },
        onError: controller.addError,
      );
      subD = streamD.listen(
        (d) {
          latestD = d;
          hasD = true;
          emit();
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
      await subD?.cancel();
    },
  );
  return controller.stream;
}
