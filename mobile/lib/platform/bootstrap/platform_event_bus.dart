import 'dart:async';

/// Reusable Event Bus to facilitate decoupled, event-driven module coordination.
class PlatformEventBus {
  PlatformEventBus._();
  static final PlatformEventBus instance = PlatformEventBus._();

  final _streamController = StreamController<dynamic>.broadcast();

  Stream<T> on<T>() {
    return _streamController.stream.where((event) => event is T).cast<T>();
  }

  void fire(dynamic event) {
    _streamController.add(event);
  }
}
