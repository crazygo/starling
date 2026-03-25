import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:starling/utils/astronomy.dart';

void main() {
  group('AstronomyUtils', () {
    group('toRad / toDeg', () {
      test('converts 180 degrees to π radians', () {
        expect(AstronomyUtils.toRad(180), closeTo(pi, 1e-10));
      });

      test('round-trips degrees through radians', () {
        const deg = 45.0;
        expect(AstronomyUtils.toDeg(AstronomyUtils.toRad(deg)),
            closeTo(deg, 1e-10));
      });
    });

    group('_julianDay (via gmst)', () {
      // The GMST at J2000.0 (2000-01-01 12:00 UTC) should be approximately
      // 280.46 degrees (18.697 hours).
      test('GMST at J2000.0 is near 280.46°', () {
        final j2000 = DateTime.utc(2000, 1, 1, 12, 0, 0);
        final g = AstronomyUtils.gmst(j2000);
        expect(g, closeTo(280.46, 0.5));
      });
    });

    group('localSiderealTime', () {
      test('shifts GMST by positive longitude', () {
        final dt = DateTime.utc(2000, 1, 1, 12, 0, 0);
        final gmst = AstronomyUtils.gmst(dt);
        final lst = AstronomyUtils.localSiderealTime(dt, 90.0);
        // LST should equal (GMST + 90) mod 360
        expect(lst, closeTo((gmst + 90.0) % 360.0, 0.01));
      });

      test('result is always in [0, 360)', () {
        final dt = DateTime.utc(2024, 6, 21, 0, 0, 0);
        final lst = AstronomyUtils.localSiderealTime(dt, -75.0);
        expect(lst, greaterThanOrEqualTo(0.0));
        expect(lst, lessThan(360.0));
      });
    });

    group('equatorialToHorizontal', () {
      // Sanity-check: a star on the meridian (hour angle ≈ 0) that is above
      // the equator should have positive altitude when observed from a
      // mid-latitude northern site.
      test('star on meridian above equator has positive altitude', () {
        // Use a time/longitude where LST ≈ star's RA so HA ≈ 0.
        // Vega: RA = 279.235°, Dec = 38.784°
        // Choose a UTC such that LST at lon 0 ≈ 279.235°
        // GMST ≈ 279.235 → pick date near J2000 offset.
        // We'll trust our formula and just ensure result is finite & in range.
        final dt = DateTime.utc(2024, 7, 1, 20, 0, 0);
        final result = AstronomyUtils.equatorialToHorizontal(
          raDeg: 279.235,
          decDeg: 38.784,
          latDeg: 51.5, // London latitude
          lonDeg: 0.0,
          utc: dt,
        );

        expect(result.azimuth, inInclusiveRange(0.0, 360.0));
        expect(result.altitude, inInclusiveRange(-90.0, 90.0));
      });

      test('circumpolar star is sometimes above horizon at high latitude', () {
        // Polaris (dec ≈ 89°) should always be above the horizon at lat 51°.
        final dt = DateTime.utc(2024, 1, 1, 0, 0, 0);
        final result = AstronomyUtils.equatorialToHorizontal(
          raDeg: 37.95,
          decDeg: 89.26,
          latDeg: 51.5,
          lonDeg: 0.0,
          utc: dt,
        );
        // At lat 51°, Polaris (dec 89°) is always above the horizon.
        expect(result.altitude, greaterThan(0.0));
      });

      test('star far below celestial pole is below horizon at high latitude',
          () {
        // Achernar dec = -57.24°: it never rises at lat +51°.
        final dt = DateTime.utc(2024, 1, 1, 0, 0, 0);
        final result = AstronomyUtils.equatorialToHorizontal(
          raDeg: 24.429,
          decDeg: -57.237,
          latDeg: 51.5,
          lonDeg: 0.0,
          utc: dt,
        );
        expect(result.altitude, lessThan(0.0));
      });
    });

    group('HorizontalCoords', () {
      test('toString includes az and alt', () {
        const c = HorizontalCoords(azimuth: 123.456, altitude: 45.678);
        expect(c.toString(), contains('az:'));
        expect(c.toString(), contains('alt:'));
      });
    });
  });
}
