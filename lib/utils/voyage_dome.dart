const double kBeijingLatitude = 39.9042;
const double kBeijingLongitude = 116.4074;
const double kDomeDefaultAltitude = 18.0;

class SeasonalDomeCamera {
  final double azimuthDeg;
  final double altitudeDeg;
  final double zoom;

  const SeasonalDomeCamera({
    required this.azimuthDeg,
    required this.altitudeDeg,
    this.zoom = 1.0,
  });
}

double wrapDegrees360(double degrees) {
  var wrapped = degrees % 360.0;
  if (wrapped < 0) wrapped += 360.0;
  return wrapped;
}

double wrapDegrees180(double degrees) {
  var wrapped = wrapDegrees360(degrees);
  if (wrapped > 180.0) wrapped -= 360.0;
  return wrapped;
}

double clampDomeAltitude(double altitudeDeg) {
  return altitudeDeg.clamp(-90.0, 90.0).toDouble();
}

SeasonalDomeCamera seasonalDomeCamera({
  required DateTime localDateTime,
  required double latitudeDeg,
}) {
  final month = localDateTime.month;
  final hemisphereBaseAzimuth = latitudeDeg >= 0 ? 180.0 : 0.0;

  double seasonalBias;
  if (month == 11 || month == 12 || month == 1 || month == 2) {
    seasonalBias = 0.0;
  } else if (month >= 3 && month <= 5) {
    seasonalBias = 30.0;
  } else if (month >= 6 && month <= 8) {
    seasonalBias = -30.0;
  } else {
    seasonalBias = 0.0;
  }

  return SeasonalDomeCamera(
    azimuthDeg: wrapDegrees360(hemisphereBaseAzimuth + seasonalBias),
    altitudeDeg: kDomeDefaultAltitude,
    zoom: 1.0,
  );
}
