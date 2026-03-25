import 'dart:async';
import 'package:location/location.dart';

/// Wraps the [Location] plugin and exposes a stream of [LocationData].
///
/// Call [start] once to begin listening; call [stop] to cancel and release
/// resources.
class LocationService {
  final Location _location = Location();

  StreamSubscription<LocationData>? _subscription;
  final StreamController<LocationData> _controller =
      StreamController<LocationData>.broadcast();

  LocationData? _lastKnown;

  /// Fires whenever a new location fix arrives.
  Stream<LocationData> get locationStream => _controller.stream;

  /// The most-recently received fix, or `null` if none yet.
  LocationData? get lastKnown => _lastKnown;

  /// Request permissions, enable the service, then start streaming updates.
  ///
  /// If already subscribed, returns immediately without creating a duplicate
  /// subscription.
  Future<void> start() async {
    if (_subscription != null) return;

    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) return;
    }

    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 5000,
      distanceFilter: 10,
    );

    _subscription = _location.onLocationChanged.listen((data) {
      _lastKnown = data;
      _controller.add(data);
    });
  }

  /// Cancel the subscription without closing the broadcast stream, allowing
  /// [start] to be called again later.  Call [dispose] when the service is
  /// permanently shut down.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Cancel the subscription and close the underlying stream controller.
  /// Do not call [start] after disposing.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
