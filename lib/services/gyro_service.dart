import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

/// Wraps the [sensors_plus] gyroscope stream and accumulates orientation
/// deltas that the star-chart can consume to pan the viewport.
class GyroService {
  StreamSubscription<GyroscopeEvent>? _subscription;
  final StreamController<GyroscopeEvent> _controller =
      StreamController<GyroscopeEvent>.broadcast();

  bool _active = false;

  /// Whether the gyroscope stream is currently active.
  bool get isActive => _active;

  /// Raw gyroscope events (rad/s around x, y, z axes).
  Stream<GyroscopeEvent> get gyroStream => _controller.stream;

  /// Start listening to the device gyroscope.
  void start() {
    if (_active) return;
    _active = true;
    _subscription = gyroscopeEventStream().listen(
      (event) => _controller.add(event),
      cancelOnError: false,
    );
  }

  /// Pause listening without closing the broadcast stream.
  void stop() {
    _active = false;
    _subscription?.cancel();
    _subscription = null;
  }

  /// Release all resources.  Do not call [start] after disposing.
  void dispose() {
    stop();
    _controller.close();
  }
}
