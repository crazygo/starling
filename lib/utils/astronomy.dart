import 'dart:math';

/// Astronomical coordinate conversion utilities.
///
/// Converts between equatorial coordinates (Right Ascension / Declination)
/// and horizontal (local) coordinates (Azimuth / Altitude) for a given
/// observer position and time.
class AstronomyUtils {
  /// Convert degrees to radians.
  static double toRad(double deg) => deg * pi / 180.0;

  /// Convert radians to degrees.
  static double toDeg(double rad) => rad * 180.0 / pi;

  /// Compute Greenwich Mean Sidereal Time (GMST) in degrees for a given UTC
  /// [DateTime], normalised to [0, 360).
  ///
  /// Formula based on the J2000.0 epoch.
  static double gmst(DateTime utc) {
    final jd = _julianDay(utc);
    final t = (jd - 2451545.0) / 36525.0;
    // GMST in degrees at 0h UT
    double theta = 280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * t * t -
        (t * t * t) / 38710000.0;
    return (theta % 360.0 + 360.0) % 360.0; // degrees, normalised to [0, 360)
  }

  /// Compute the Local Sidereal Time (LST) in degrees for an observer at
  /// [longitudeDeg] (east-positive) and a given UTC [DateTime].
  static double localSiderealTime(DateTime utc, double longitudeDeg) {
    return (gmst(utc) + longitudeDeg + 360.0) % 360.0;
  }

  /// Convert equatorial coordinates to horizontal (Az/Alt) for an observer.
  ///
  /// Parameters:
  /// - [raDeg]: Right Ascension in degrees (0–360).
  /// - [decDeg]: Declination in degrees (−90 to +90).
  /// - [latDeg]: Observer latitude in degrees (north-positive).
  /// - [lonDeg]: Observer longitude in degrees (east-positive).
  /// - [utc]: Observation time in UTC.
  ///
  /// Returns a [HorizontalCoords] record with azimuth (°, N=0, E=90) and
  /// altitude (°, horizon=0, zenith=90).
  static HorizontalCoords equatorialToHorizontal({
    required double raDeg,
    required double decDeg,
    required double latDeg,
    required double lonDeg,
    required DateTime utc,
  }) {
    final lst = localSiderealTime(utc, lonDeg); // degrees
    final hourAngle = (lst - raDeg + 360.0) % 360.0; // degrees

    final hRad = toRad(hourAngle);
    final decRad = toRad(decDeg);
    final latRad = toRad(latDeg);

    // Altitude
    final sinAlt =
        sin(decRad) * sin(latRad) + cos(decRad) * cos(latRad) * cos(hRad);
    final altitude = toDeg(asin(sinAlt.clamp(-1.0, 1.0)));

    // Azimuth (measured from North through East)
    final cosA = (sin(decRad) - sin(toRad(altitude)) * sin(latRad)) /
        (cos(toRad(altitude)) * cos(latRad));
    double azimuth = toDeg(acos(cosA.clamp(-1.0, 1.0)));
    if (sin(hRad) > 0) {
      azimuth = 360.0 - azimuth;
    }

    return HorizontalCoords(azimuth: azimuth, altitude: altitude);
  }

  /// Convert horizontal coordinates (Az/Alt) to equatorial (RA/Dec).
  ///
  /// Parameters:
  /// - [azimuthDeg]: Azimuth in degrees (N=0, E=90).
  /// - [altitudeDeg]: Altitude in degrees (horizon=0, zenith=90).
  /// - [latDeg]: Observer latitude in degrees (north-positive).
  /// - [lonDeg]: Observer longitude in degrees (east-positive).
  /// - [utc]: Observation time in UTC.
  ///
  /// Returns an [EquatorialCoords] record with right ascension (°, 0–360)
  /// and declination (°, −90 to +90).
  static EquatorialCoords horizontalToEquatorial({
    required double azimuthDeg,
    required double altitudeDeg,
    required double latDeg,
    required double lonDeg,
    required DateTime utc,
  }) {
    final azRad = toRad(azimuthDeg);
    final altRad = toRad(altitudeDeg);
    final latRad = toRad(latDeg);

    final sinDec =
        sin(altRad) * sin(latRad) + cos(altRad) * cos(latRad) * cos(azRad);
    final decRad = asin(sinDec.clamp(-1.0, 1.0));

    final sinH = -sin(azRad) * cos(altRad) / cos(decRad);
    final cosH =
        (sin(altRad) - sin(latRad) * sin(decRad)) / (cos(latRad) * cos(decRad));
    var hourAngleDeg = toDeg(atan2(sinH, cosH));
    if (hourAngleDeg < 0) hourAngleDeg += 360.0;

    final lst = localSiderealTime(utc, lonDeg);
    final raDeg = (lst - hourAngleDeg + 360.0) % 360.0;

    return EquatorialCoords(rightAscension: raDeg, declination: toDeg(decRad));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Compute the Julian Day Number for a given UTC [DateTime].
  static double _julianDay(DateTime utc) {
    final y = utc.year;
    final m = utc.month;
    final d =
        utc.day + utc.hour / 24.0 + utc.minute / 1440.0 + utc.second / 86400.0;

    int a = (14 - m) ~/ 12;
    int y1 = y + 4800 - a;
    int m1 = m + 12 * a - 3;

    double jdn = d +
        (153 * m1 + 2) ~/ 5 +
        365 * y1 +
        y1 ~/ 4 -
        y1 ~/ 100 +
        y1 ~/ 400 -
        32045;
    return jdn - 0.5; // Julian Day (noon = integer)
  }
}

/// A pair of equatorial coordinates.
class EquatorialCoords {
  /// Right ascension in degrees, normalised to [0, 360).
  final double rightAscension;

  /// Declination in degrees (−90 to +90).
  final double declination;

  const EquatorialCoords({
    required this.rightAscension,
    required this.declination,
  });

  @override
  String toString() =>
      'EquatorialCoords(ra: ${rightAscension.toStringAsFixed(2)}°, dec: ${declination.toStringAsFixed(2)}°)';
}

/// A pair of horizontal coordinates.
class HorizontalCoords {
  /// Azimuth in degrees, measured from North (0°) clockwise through East (90°).
  final double azimuth;

  /// Altitude in degrees, measured from the horizon (0°) upward to the zenith
  /// (90°).
  final double altitude;

  const HorizontalCoords({required this.azimuth, required this.altitude});

  @override
  String toString() =>
      'HorizontalCoords(az: ${azimuth.toStringAsFixed(2)}°, alt: ${altitude.toStringAsFixed(2)}°)';
}
