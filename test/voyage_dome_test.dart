import 'package:flutter_test/flutter_test.dart';
import 'package:starling/utils/voyage_dome.dart';

void main() {
  group('voyage dome helpers', () {
    test('clamps dome altitude to full-sphere range', () {
      expect(clampDomeAltitude(120.0), 90.0);
      expect(clampDomeAltitude(-120.0), -90.0);
      expect(clampDomeAltitude(18.0), 18.0);
    });

    test('seasonal dome viewport faces south in northern hemisphere winter',
        () {
      final camera = seasonalDomeCamera(
        localDateTime: DateTime(2026, 1, 15, 22),
        latitudeDeg: 39.9,
      );

      expect(camera.azimuthDeg, closeTo(180.0, 0.001));
      expect(camera.altitudeDeg, closeTo(kDomeDefaultAltitude, 0.001));
    });

    test('seasonal dome viewport faces north in southern hemisphere summer',
        () {
      final camera = seasonalDomeCamera(
        localDateTime: DateTime(2026, 1, 15, 22),
        latitudeDeg: -33.8,
      );

      expect(camera.azimuthDeg, closeTo(0.0, 0.001));
      expect(camera.altitudeDeg, closeTo(kDomeDefaultAltitude, 0.001));
    });
  });
}
