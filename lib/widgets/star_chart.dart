import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/star.dart';
import '../models/constellation.dart';
import '../services/settings_service.dart';
import '../utils/astronomy.dart';
import '../utils/voyage_dome.dart';

const double _classicDegreesPerPixelAtZoom1 = 0.15;
const double _domeDegreesPerPixelAtZoom1 = 0.15;

@visibleForTesting
double classicDegreesPerPixelForZoom(double zoom) {
  return _classicDegreesPerPixelAtZoom1 / zoom;
}

@visibleForTesting
Offset classicHalfSpanForSize(Size size, double zoom) {
  final degPerPixel = classicDegreesPerPixelForZoom(zoom);
  return Offset(
    (size.width / 2) * degPerPixel,
    (size.height / 2) * degPerPixel,
  );
}

@visibleForTesting
double domeDegreesPerPixelForZoom(double zoom) {
  return _domeDegreesPerPixelAtZoom1 / zoom;
}

@visibleForTesting
double domeFocalLengthForZoom(double zoom) {
  return 1 / AstronomyUtils.toRad(domeDegreesPerPixelForZoom(zoom));
}

@visibleForTesting
double domeHorizontalFovForSize(Size size, double zoom) {
  return AstronomyUtils.toDeg(
    2 * atan((size.width / 2) / domeFocalLengthForZoom(zoom)),
  );
}

@visibleForTesting
double domeVerticalFovForSize(Size size, double zoom) {
  return AstronomyUtils.toDeg(
    2 * atan((size.height / 2) / domeFocalLengthForZoom(zoom)),
  );
}

double _effectiveCenterDecForStyle(
  ViewStyle viewStyle,
  double baseCenterDec,
  double gyroDec,
) {
  final effectiveDec = baseCenterDec + gyroDec;
  if (viewStyle == ViewStyle.dome) {
    return clampDomeAltitude(effectiveDec);
  }
  return effectiveDec.clamp(-90.0, 90.0).toDouble();
}

double _effectiveCenterRaForStyle(
  ViewStyle viewStyle,
  double baseCenterRa,
  double gyroRa,
) {
  final effectiveRa = baseCenterRa + gyroRa;
  if (viewStyle == ViewStyle.dome) {
    return wrapDegrees360(effectiveRa);
  }
  var wrapped = effectiveRa % 360.0;
  if (wrapped < 0) wrapped += 360.0;
  return wrapped;
}

class _Vec3 {
  final double x;
  final double y;
  final double z;

  const _Vec3(this.x, this.y, this.z);

  double dot(_Vec3 other) => x * other.x + y * other.y + z * other.z;
}

_Vec3 _horizontalVector(double azimuthDeg, double altitudeDeg) {
  final az = AstronomyUtils.toRad(azimuthDeg);
  final alt = AstronomyUtils.toRad(altitudeDeg);
  final cosAlt = cos(alt);
  return _Vec3(cosAlt * sin(az), cosAlt * cos(az), sin(alt));
}

class _ProjectedPoint {
  final Offset screenOffset;
  final double cameraX;
  final double cameraY;
  final double cameraZ;

  const _ProjectedPoint({
    required this.screenOffset,
    required this.cameraX,
    required this.cameraY,
    required this.cameraZ,
  });
}

class _DomeProjection {
  final Size size;
  final double centerAzimuthDeg;
  final double centerAltitudeDeg;
  final double zoom;

  late final _Vec3 _forward = _horizontalVector(
    centerAzimuthDeg,
    centerAltitudeDeg,
  );
  late final _Vec3 _right = _Vec3(
    cos(AstronomyUtils.toRad(centerAzimuthDeg)),
    -sin(AstronomyUtils.toRad(centerAzimuthDeg)),
    0,
  );
  late final _Vec3 _up = _Vec3(
    _right.y * _forward.z - _right.z * _forward.y,
    _right.z * _forward.x - _right.x * _forward.z,
    _right.x * _forward.y - _right.y * _forward.x,
  );
  late final double _focalLength = (size.width / 2) /
      tan(AstronomyUtils.toRad(domeHorizontalFovForSize(size, zoom)) / 2);

  _DomeProjection({
    required this.size,
    required this.centerAzimuthDeg,
    required this.centerAltitudeDeg,
    required this.zoom,
  });

  _ProjectedPoint? projectHorizontal(
    double azimuthDeg,
    double altitudeDeg, {
    double minDepth = 0.02,
  }) {
    final vector = _horizontalVector(azimuthDeg, altitudeDeg);
    final cameraX = vector.dot(_right);
    final cameraY = vector.dot(_up);
    final cameraZ = vector.dot(_forward);
    if (cameraZ <= minDepth) return null;

    final projected = Offset(
      size.width / 2 + (cameraX / cameraZ) * _focalLength,
      size.height / 2 - (cameraY / cameraZ) * _focalLength,
    );
    return _ProjectedPoint(
      screenOffset: projected,
      cameraX: cameraX,
      cameraY: cameraY,
      cameraZ: cameraZ,
    );
  }

  Offset pinToEdgeForHorizontal(double azimuthDeg, double altitudeDeg) {
    final vector = _horizontalVector(azimuthDeg, altitudeDeg);
    var dx = vector.dot(_right);
    var dy = -vector.dot(_up);
    if (vector.dot(_forward) < 0) {
      dx = -dx;
      dy = -dy;
    }
    final direction = Offset(dx, dy);
    if (direction.distance < 1e-6) {
      return Offset(size.width / 2, size.height / 2);
    }

    final center = Offset(size.width / 2, size.height / 2);
    final normalized = direction / direction.distance;
    final scaleX = normalized.dx.abs() > 1e-6
        ? (normalized.dx > 0
            ? (size.width - center.dx) / normalized.dx
            : -center.dx / normalized.dx)
        : double.infinity;
    final scaleY = normalized.dy.abs() > 1e-6
        ? (normalized.dy > 0
            ? (size.height - center.dy) / normalized.dy
            : -center.dy / normalized.dy)
        : double.infinity;
    final scale = min(scaleX.abs(), scaleY.abs());
    final pinned = center + normalized * scale;
    return Offset(
      pinned.dx.clamp(18.0, size.width - 18.0),
      pinned.dy.clamp(18.0, size.height - 18.0),
    );
  }
}

/// The visible viewport state: centre offset and zoom factor.
class StarChartViewport {
  /// Offset of the viewport centre in the equatorial plane (degrees).
  final double centerRa;
  final double centerDec;

  /// Zoom factor: higher values show a smaller area.
  final double zoom;

  const StarChartViewport({
    this.centerRa = 180.0,
    this.centerDec = 45.0,
    this.zoom = 1.0,
  });

  StarChartViewport copyWith({
    double? centerRa,
    double? centerDec,
    double? zoom,
  }) =>
      StarChartViewport(
        centerRa: centerRa ?? this.centerRa,
        centerDec: centerDec ?? this.centerDec,
        zoom: zoom ?? this.zoom,
      );
}

/// Interactive star chart that renders stars and constellation lines on a
/// dark canvas.
///
/// Supports:
/// - Pinch-to-zoom
/// - Drag-to-pan
/// - Tap-to-select a star
/// - Trackpad two-finger scroll to pan (desktop/web)
/// - Trackpad pinch-to-zoom (desktop/web)
class StarChart extends StatefulWidget {
  final List<Star> stars;
  final List<Constellation> constellations;

  /// Chinese asterisms used by the label system even when [showChineseName]
  /// is false (so the painter always has access to both cultures).
  final List<Constellation> chineseConstellations;

  /// When true, label text uses Chinese names and the Chinese asterism system
  /// is used for Group 2 labels.
  final bool showChineseName;
  final ViewStyle viewStyle;
  final double observerLatitude;
  final double observerLongitude;
  final DateTime observationTimeUtc;
  final bool majorStarsOnlyLabels;
  final StarRenderCondition starRenderCondition;
  final bool showHorizonGrid;
  final bool showCelestialGrid;

  final StarChartViewport viewport;
  final ValueChanged<StarChartViewport> onViewportChanged;
  final ValueChanged<Star>? onStarTapped;

  /// When non-null, the chart is in gyroscope mode and [gyroOffset] (dx, dy)
  /// in degrees is applied on top of the [viewport].
  final Offset? gyroOffset;

  const StarChart({
    super.key,
    required this.stars,
    required this.constellations,
    required this.chineseConstellations,
    required this.showChineseName,
    required this.viewStyle,
    required this.observerLatitude,
    required this.observerLongitude,
    required this.observationTimeUtc,
    required this.majorStarsOnlyLabels,
    required this.starRenderCondition,
    required this.showHorizonGrid,
    required this.showCelestialGrid,
    required this.viewport,
    required this.onViewportChanged,
    this.onStarTapped,
    this.gyroOffset,
  });

  @override
  State<StarChart> createState() => _StarChartState();
}

class _StarChartState extends State<StarChart> {
  Offset? _panStart;
  StarChartViewport? _viewportAtGestureStart;

  void _onScaleStart(ScaleStartDetails d) {
    _panStart = d.localFocalPoint;
    _viewportAtGestureStart = widget.viewport;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final base = _viewportAtGestureStart!;

    final delta = d.localFocalPoint - _panStart!;
    final degPerPxH = widget.viewStyle == ViewStyle.dome
        ? domeDegreesPerPixelForZoom(base.zoom)
        : classicDegreesPerPixelForZoom(base.zoom);
    final degPerPxV = widget.viewStyle == ViewStyle.dome
        ? domeDegreesPerPixelForZoom(base.zoom)
        : classicDegreesPerPixelForZoom(base.zoom);

    double newRa = _effectiveCenterRaForStyle(
      widget.viewStyle,
      base.centerRa,
      -delta.dx * degPerPxH,
    );
    double newDec = base.centerDec + delta.dy * degPerPxV;
    newDec = widget.viewStyle == ViewStyle.dome
        ? clampDomeAltitude(newDec)
        : newDec.clamp(-90.0, 90.0);

    final newZoom = (base.zoom * d.scale).clamp(0.3, 10.0);

    widget.onViewportChanged(
      base.copyWith(centerRa: newRa, centerDec: newDec, zoom: newZoom),
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Two-finger trackpad scroll → pan
      final vp = widget.viewport;
      final degPerPxH = widget.viewStyle == ViewStyle.dome
          ? domeDegreesPerPixelForZoom(vp.zoom)
          : classicDegreesPerPixelForZoom(vp.zoom);
      final degPerPxV = widget.viewStyle == ViewStyle.dome
          ? domeDegreesPerPixelForZoom(vp.zoom)
          : classicDegreesPerPixelForZoom(vp.zoom);

      final newRa = _effectiveCenterRaForStyle(
        widget.viewStyle,
        vp.centerRa,
        event.scrollDelta.dx * degPerPxH,
      );
      final rawDec = vp.centerDec - event.scrollDelta.dy * degPerPxV;
      final newDec = widget.viewStyle == ViewStyle.dome
          ? clampDomeAltitude(rawDec)
          : rawDec.clamp(-90.0, 90.0);

      widget.onViewportChanged(vp.copyWith(centerRa: newRa, centerDec: newDec));
    } else if (event is PointerScaleEvent) {
      // Two-finger trackpad pinch → zoom
      final vp = widget.viewport;
      final newZoom = (vp.zoom * event.scale).clamp(0.3, 10.0);
      widget.onViewportChanged(vp.copyWith(zoom: newZoom));
    }
  }

  void _onTapUp(TapUpDetails d) {
    if (widget.onStarTapped == null) return;
    final size = context.size ?? const Size(400, 800);
    final star = _hitTest(d.localPosition, size);
    if (star != null) widget.onStarTapped!(star);
  }

  Star? _hitTest(Offset tapPos, Size size) {
    const hitRadius = 16.0;
    for (final star in widget.stars) {
      final pos = _projectStar(star, size);
      if (pos == null) continue;
      if ((tapPos - pos).distance < hitRadius) return star;
    }
    return null;
  }

  /// Project a star from equatorial coords to canvas pixels. Returns `null`
  /// if the star is outside the current viewport.
  Offset? _projectStar(Star star, Size size) {
    if (widget.viewStyle == ViewStyle.dome) {
      final projection = _DomeProjection(
        size: size,
        centerAzimuthDeg: _effectiveCenterRaForStyle(
          widget.viewStyle,
          widget.viewport.centerRa,
          widget.gyroOffset?.dx ?? 0,
        ),
        centerAltitudeDeg: _effectiveCenterDecForStyle(
          widget.viewStyle,
          widget.viewport.centerDec,
          widget.gyroOffset?.dy ?? 0,
        ),
        zoom: widget.viewport.zoom,
      );
      final horizontal = AstronomyUtils.equatorialToHorizontal(
        raDeg: star.rightAscension,
        decDeg: star.declination,
        latDeg: widget.observerLatitude,
        lonDeg: widget.observerLongitude,
        utc: widget.observationTimeUtc,
      );
      return projection
          .projectHorizontal(horizontal.azimuth, horizontal.altitude)
          ?.screenOffset;
    }

    final vp = widget.viewport;
    final effectiveRa = _effectiveCenterRaForStyle(
      widget.viewStyle,
      vp.centerRa,
      widget.gyroOffset?.dx ?? 0,
    );
    final effectiveDec = _effectiveCenterDecForStyle(
      widget.viewStyle,
      vp.centerDec,
      widget.gyroOffset?.dy ?? 0,
    );

    final halfSpan = classicHalfSpanForSize(size, vp.zoom);
    final halfW = halfSpan.dx;
    final halfH = halfSpan.dy;

    double dRa = star.rightAscension - effectiveRa;
    if (dRa > 180) dRa -= 360;
    if (dRa < -180) dRa += 360;
    final dDec = star.declination - effectiveDec;

    if (dRa.abs() > halfW || dDec.abs() > halfH) return null;

    return Offset(
      (size.width / 2) + (dRa / halfW) * (size.width / 2),
      (size.height / 2) - (dDec / halfH) * (size.height / 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onTapUp: _onTapUp,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return CustomPaint(
              painter: _StarPainter(
                stars: widget.stars,
                constellations: widget.constellations,
                chineseConstellations: widget.chineseConstellations,
                showChineseName: widget.showChineseName,
                viewStyle: widget.viewStyle,
                observerLatitude: widget.observerLatitude,
                observerLongitude: widget.observerLongitude,
                observationTimeUtc: widget.observationTimeUtc,
                majorStarsOnlyLabels: widget.majorStarsOnlyLabels,
                starRenderCondition: widget.starRenderCondition,
                showHorizonGrid: widget.showHorizonGrid,
                showCelestialGrid: widget.showCelestialGrid,
                viewport: widget.viewport,
                gyroOffset: widget.gyroOffset,
                size: size,
              ),
              size: size,
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Label Rendering Data Structures
// ---------------------------------------------------------------------------

/// A resolved label ready to be drawn on the canvas.
class _LabelSpec {
  final Offset textPos; // top-left where the paragraph will be drawn
  final Rect rect; // bounding rect (text + padding) used for overlap detection
  final String text;
  final double fontSize;
  final Color color; // alpha already baked in

  const _LabelSpec({
    required this.textPos,
    required this.rect,
    required this.text,
    required this.fontSize,
    required this.color,
  });
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _StarPainter extends CustomPainter {
  final List<Star> stars;
  final List<Constellation> constellations;
  final List<Constellation> chineseConstellations;
  final bool showChineseName;
  final ViewStyle viewStyle;
  final double observerLatitude;
  final double observerLongitude;
  final DateTime observationTimeUtc;
  final bool majorStarsOnlyLabels;
  final StarRenderCondition starRenderCondition;
  final bool showHorizonGrid;
  final bool showCelestialGrid;
  final StarChartViewport viewport;
  final Offset? gyroOffset;
  final Size size;

  // Normalized [0, 1) background star positions precomputed once.
  // Using a fixed seed means the pattern is deterministic and stable.
  static final List<Offset> _bgStarPositions = _precomputeBgStars();

  // Important celestial objects whitelist (matched against star.name).
  static const _importantNames = {
    'Sun',
    'Moon',
    'Mercury',
    'Venus',
    'Mars',
    'Jupiter',
    'Saturn',
    'Uranus',
    'Neptune',
  };

  // Pattern for auto-generated HIP identifiers that have no real proper name.
  static final _hipRegex = RegExp(r'^HIP \d+$');

  // Label placement constants.
  static const _labelHorizontalOffset = 6.0; // px gap between star and label
  static const _labelVerticalOffset = 2.0; // px gap below star centre
  static const _labelPadding = 8.0; // inflate label rect for overlap detection
  static const _labelTextHeightExtra = 4.0; // extra height beyond font size
  static const _maxCompetitiveLabels = 20; // Group 3 cap

  // Cached label specs — one computation per painter instance.
  // Since _StarPainter is recreated on every build(), the cache is
  // automatically fresh: it starts null, is filled on the first paint(),
  // and is discarded when the widget rebuilds with changed properties.
  List<_LabelSpec>? _cachedLabelSpecs;
  final Map<String, Offset?> _projectedStarCache = {};
  final Map<String, HorizontalCoords> _horizontalStarCache = {};
  final Map<String, double> _starRadiusCache = {};

  // Star IDs that belong to the drawn constellation lines (always western).
  // Used by _drawStars() to exempt member stars from magnitude culling so
  // constellation lines never break when zooming out.
  late final Set<String> _constellationMemberStarIds = {
    for (final c in constellations)
      for (final id in c.starIds) id,
  };

  // Star IDs that belong to the culture-specific (Group-2) constellation list.
  // Used by _buildLabelSpecs() for label grouping.  Reuses the western set
  // when showChineseName is false to avoid duplicate work.
  late final Set<String> _labelMemberStarIds = showChineseName
      ? {
          for (final c in chineseConstellations)
            for (final id in c.starIds) id,
        }
      : _constellationMemberStarIds;

  static List<Offset> _precomputeBgStars() {
    final rng = Random(42);
    return List.generate(
      300,
      (_) => Offset(rng.nextDouble(), rng.nextDouble()),
    );
  }

  _StarPainter({
    required this.stars,
    required this.constellations,
    required this.chineseConstellations,
    required this.showChineseName,
    required this.viewStyle,
    required this.observerLatitude,
    required this.observerLongitude,
    required this.observationTimeUtc,
    required this.majorStarsOnlyLabels,
    required this.starRenderCondition,
    required this.showHorizonGrid,
    required this.showCelestialGrid,
    required this.viewport,
    required this.size,
    this.gyroOffset,
  });

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.viewport != viewport ||
      old.gyroOffset != gyroOffset ||
      old.stars != stars ||
      old.constellations != constellations ||
      old.chineseConstellations != chineseConstellations ||
      old.showChineseName != showChineseName ||
      old.viewStyle != viewStyle ||
      old.observerLatitude != observerLatitude ||
      old.observerLongitude != observerLongitude ||
      old.observationTimeUtc != observationTimeUtc ||
      old.majorStarsOnlyLabels != majorStarsOnlyLabels ||
      old.starRenderCondition != starRenderCondition ||
      old.showHorizonGrid != showHorizonGrid ||
      old.showCelestialGrid != showCelestialGrid ||
      old.size != size;

  Offset? _project(double raDeg, double decDeg) {
    if (viewStyle == ViewStyle.dome) {
      final projection = _domeProjection();
      final horizontal = AstronomyUtils.equatorialToHorizontal(
        raDeg: raDeg,
        decDeg: decDeg,
        latDeg: observerLatitude,
        lonDeg: observerLongitude,
        utc: observationTimeUtc,
      );
      return projection
          .projectHorizontal(horizontal.azimuth, horizontal.altitude)
          ?.screenOffset;
    }

    final vp = viewport;
    final effectiveRa = _effectiveCenterRaForStyle(
      viewStyle,
      vp.centerRa,
      gyroOffset?.dx ?? 0,
    );
    final effectiveDec = _effectiveCenterDecForStyle(
      viewStyle,
      vp.centerDec,
      gyroOffset?.dy ?? 0,
    );

    final halfSpan = classicHalfSpanForSize(size, vp.zoom);
    final halfW = halfSpan.dx;
    final halfH = halfSpan.dy;

    double dRa = raDeg - effectiveRa;
    if (dRa > 180) dRa -= 360;
    if (dRa < -180) dRa += 360;
    final dDec = decDeg - effectiveDec;

    if (dRa.abs() > halfW * 1.1 || dDec.abs() > halfH * 1.1) return null;

    final px = (size.width / 2) + (dRa / halfW) * (size.width / 2);
    final linearPy = (size.height / 2) - (dDec / halfH) * (size.height / 2);
    return Offset(px, linearPy);
  }

  _DomeProjection _domeProjection() {
    return _DomeProjection(
      size: size,
      centerAzimuthDeg: _effectiveCenterRaForStyle(
        viewStyle,
        viewport.centerRa,
        gyroOffset?.dx ?? 0,
      ),
      centerAltitudeDeg: _effectiveCenterDecForStyle(
        viewStyle,
        viewport.centerDec,
        gyroOffset?.dy ?? 0,
      ),
      zoom: viewport.zoom,
    );
  }

  HorizontalCoords _horizontalForStar(Star star) {
    return _horizontalStarCache.putIfAbsent(
      star.id,
      () => AstronomyUtils.equatorialToHorizontal(
        raDeg: star.rightAscension,
        decDeg: star.declination,
        latDeg: observerLatitude,
        lonDeg: observerLongitude,
        utc: observationTimeUtc,
      ),
    );
  }

  Offset? _projectStar(Star star) {
    return _projectedStarCache.putIfAbsent(star.id, () {
      if (viewStyle == ViewStyle.dome) {
        final horizontal = _horizontalForStar(star);
        return _domeProjection()
            .projectHorizontal(horizontal.azimuth, horizontal.altitude)
            ?.screenOffset;
      }
      return _project(star.rightAscension, star.declination);
    });
  }

  bool _isNearVisibleBounds(Offset offset) {
    const margin = 16.0;
    return offset.dx >= -margin &&
        offset.dx <= size.width + margin &&
        offset.dy >= -margin &&
        offset.dy <= size.height + margin;
  }

  double _renderRadiusForStar(Star star) {
    return _starRadiusCache.putIfAbsent(
      star.id,
      () => ((6.5 - star.magnitude) * 0.9 * viewport.zoom).clamp(0.5, 8.0),
    );
  }

  double _labelRadiusThreshold() {
    return switch (starRenderCondition) {
      StarRenderCondition.small => 0.8,
      StarRenderCondition.medium => 1.4,
      StarRenderCondition.large => 2.0,
      StarRenderCondition.constellationOnly => 1.4,
    };
  }

  bool _showNonMemberStars() {
    return starRenderCondition != StarRenderCondition.constellationOnly;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackdrop(canvas, size);

    if (viewStyle == ViewStyle.dome) {
      _drawBackgroundStars(canvas, size);
      _drawCoordinateGrids(canvas);
      _drawConstellationLines(canvas);
      _drawStars(canvas, _constellationMemberStarIds);
      _drawLabels(canvas, size);
      _drawDomeForeground(canvas, size);
      return;
    }

    _drawBackgroundStars(canvas, size);
    _drawCoordinateGrids(canvas);
    _drawConstellationLines(canvas);
    _drawStars(canvas, _constellationMemberStarIds);
    _drawLabels(canvas, size);
  }

  void _drawBackdrop(Canvas canvas, Size size) {
    if (viewStyle == ViewStyle.classic) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF05091A),
      );
      return;
    }

    final fullRect = Offset.zero & size;
    canvas.drawRect(
      fullRect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, size.height),
          const [Color(0xFF020611), Color(0xFF07152A), Color(0xFF0A1830)],
          const [0.0, 0.58, 1.0],
        ),
    );
  }

  void _drawDomeForeground(Canvas canvas, Size size) {
    final horizonPoints = _visibleHorizonPoints();

    if (horizonPoints.length >= 2) {
      final horizonPath = Path()
        ..moveTo(horizonPoints.first.dx, horizonPoints.first.dy);
      for (final point in horizonPoints.skip(1)) {
        horizonPath.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        horizonPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0x22F7C78C)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawPath(
        horizonPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = const Color(0x66FFD9A6),
      );
    }

    _drawCardinalMarkers(canvas);

    final leftVignette = Rect.fromLTWH(0, 0, size.width * 0.18, size.height);
    canvas.drawRect(
      leftVignette,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(leftVignette.left, 0),
          Offset(leftVignette.right, 0),
          const [Color(0x66020611), Color(0x00020611)],
        ),
    );
    final rightVignette = Rect.fromLTWH(
      size.width * 0.82,
      0,
      size.width * 0.18,
      size.height,
    );
    canvas.drawRect(
      rightVignette,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(rightVignette.left, 0),
          Offset(rightVignette.right, 0),
          const [Color(0x00020611), Color(0x66020611)],
        ),
    );
  }

  List<Offset> _visibleHorizonPoints() {
    if (viewStyle != ViewStyle.dome) return const [];
    final projection = _domeProjection();
    final points = <Offset>[];
    for (var azimuth = 0; azimuth <= 360; azimuth += 2) {
      final point = projection.projectHorizontal(azimuth.toDouble(), 0.0);
      if (point == null) continue;
      final offset = point.screenOffset;
      if (offset.dx < -size.width * 0.5 ||
          offset.dx > size.width * 1.5 ||
          offset.dy < -size.height * 0.5 ||
          offset.dy > size.height * 1.5) {
        continue;
      }
      points.add(offset);
    }
    points.sort((a, b) => a.dx.compareTo(b.dx));
    return points;
  }

  void _drawCardinalMarkers(Canvas canvas) {
    final projection = _domeProjection();
    const markers = <(String, double)>[
      ('N', 0.0),
      ('E', 90.0),
      ('S', 180.0),
      ('W', 270.0),
    ];

    for (final marker in markers) {
      final label = marker.$1;
      final azimuth = marker.$2;
      final projected = projection.projectHorizontal(azimuth, 0.0);
      final offset = projected?.screenOffset;
      final markerOffset = offset != null &&
              offset.dx >= 18 &&
              offset.dx <= size.width - 18 &&
              offset.dy >= 18 &&
              offset.dy <= size.height - 18
          ? offset
          : projection.pinToEdgeForHorizontal(azimuth, 0.0);

      final paragraph = (ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center, maxLines: 1),
      )
            ..pushStyle(
              ui.TextStyle(
                color: const Color(0xCCEAD7B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            )
            ..addText(label))
          .build()
        ..layout(const ui.ParagraphConstraints(width: 24));
      canvas.drawParagraph(
        paragraph,
        Offset(markerOffset.dx - 12, markerOffset.dy - 9),
      );
    }
  }

  void _drawBackgroundStars(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = viewStyle == ViewStyle.dome
          ? Colors.white.withAlpha(56)
          : Colors.white.withAlpha(77);
    for (final pos in _bgStarPositions) {
      final bgOffset = Offset(pos.dx * size.width, pos.dy * size.height);
      canvas.drawCircle(bgOffset, 0.5, paint);
    }
  }

  void _drawCoordinateGrids(Canvas canvas) {
    if (!showHorizonGrid && !showCelestialGrid) return;
    if (showHorizonGrid) {
      _drawHorizontalGrid(canvas);
    }
    if (showCelestialGrid) {
      _drawEquatorialGrid(canvas);
    }
  }

  void _drawHorizontalGrid(Canvas canvas) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0x8846E0C8);

    for (var altitude = -60; altitude <= 60; altitude += 30) {
      _drawHorizontalCurve(canvas, linePaint, altitudeDeg: altitude.toDouble());
    }

    for (var azimuth = 0; azimuth < 360; azimuth += 30) {
      _drawAzimuthCurve(canvas, linePaint, azimuthDeg: azimuth.toDouble());
    }
  }

  void _drawEquatorialGrid(Canvas canvas) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x99FFAE5A);

    for (var dec = -60; dec <= 60; dec += 30) {
      _drawDeclinationCurve(canvas, linePaint, declinationDeg: dec.toDouble());
    }

    for (var ra = 0; ra < 360; ra += 30) {
      _drawRightAscensionCurve(
        canvas,
        linePaint,
        rightAscensionDeg: ra.toDouble(),
      );
    }
  }

  void _drawHorizontalCurve(
    Canvas canvas,
    Paint paint, {
    required double altitudeDeg,
  }) {
    final path = Path();
    var hasPoint = false;
    for (var az = 0; az <= 360; az += 2) {
      final point = _projectHorizontal(az.toDouble(), altitudeDeg);
      if (point == null || !_isNearVisibleBounds(point)) {
        hasPoint = false;
        continue;
      }
      if (!hasPoint) {
        path.moveTo(point.dx, point.dy);
        hasPoint = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawAzimuthCurve(
    Canvas canvas,
    Paint paint, {
    required double azimuthDeg,
  }) {
    final path = Path();
    var hasPoint = false;
    for (var alt = -90; alt <= 90; alt += 2) {
      final point = _projectHorizontal(azimuthDeg, alt.toDouble());
      if (point == null || !_isNearVisibleBounds(point)) {
        hasPoint = false;
        continue;
      }
      if (!hasPoint) {
        path.moveTo(point.dx, point.dy);
        hasPoint = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawDeclinationCurve(
    Canvas canvas,
    Paint paint, {
    required double declinationDeg,
  }) {
    final path = Path();
    var hasPoint = false;
    for (var ra = 0; ra <= 360; ra += 2) {
      final point = _project(ra.toDouble(), declinationDeg);
      if (point == null || !_isNearVisibleBounds(point)) {
        hasPoint = false;
        continue;
      }
      if (!hasPoint) {
        path.moveTo(point.dx, point.dy);
        hasPoint = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawRightAscensionCurve(
    Canvas canvas,
    Paint paint, {
    required double rightAscensionDeg,
  }) {
    final path = Path();
    var hasPoint = false;
    for (var dec = -90; dec <= 90; dec += 2) {
      final point = _project(rightAscensionDeg, dec.toDouble());
      if (point == null || !_isNearVisibleBounds(point)) {
        hasPoint = false;
        continue;
      }
      if (!hasPoint) {
        path.moveTo(point.dx, point.dy);
        hasPoint = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  Offset? _projectHorizontal(double azimuthDeg, double altitudeDeg) {
    if (viewStyle == ViewStyle.dome) {
      return _domeProjection()
          .projectHorizontal(azimuthDeg, altitudeDeg)
          ?.screenOffset;
    }
    final equatorial = AstronomyUtils.horizontalToEquatorial(
      azimuthDeg: azimuthDeg,
      altitudeDeg: altitudeDeg,
      latDeg: observerLatitude,
      lonDeg: observerLongitude,
      utc: observationTimeUtc,
    );
    return _project(equatorial.rightAscension, equatorial.declination);
  }

  void _drawConstellationLines(Canvas canvas) {
    final Map<String, Star> starMap = {for (final s in stars) s.id: s};
    final linePaint = Paint()
      ..color = Colors.blueGrey.withAlpha(102)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final constellation in constellations) {
      for (final line in constellation.lines) {
        final s1 = starMap[line.starId1];
        final s2 = starMap[line.starId2];
        if (s1 == null || s2 == null) continue;
        final p1 = _projectStar(s1);
        final p2 = _projectStar(s2);
        if (p1 == null || p2 == null) continue;
        canvas.drawLine(p1, p2, linePaint);
      }
    }
  }

  void _drawStars(Canvas canvas, Set<String> activeMemberStarIds) {
    // Dynamic magnitude threshold: at low zoom (zoomed out) only brighter stars
    // are shown. Formula yields ~4.5 at zoom=1.0, ~6.5 (full catalogue) at
    // zoom>=2.0, and floors at 3.0 when very zoomed out. Member stars of the
    // active constellations are always shown so constellation lines stay intact.
    final magThreshold = (2.5 + viewport.zoom * 2.0).clamp(3.0, 6.5);

    for (final star in stars) {
      final isMember = activeMemberStarIds.contains(star.id);
      if (!_showNonMemberStars() && !isMember) {
        continue;
      }

      // Cull faint non-member stars when zoomed out.
      if (star.magnitude > magThreshold && !isMember) {
        continue;
      }

      final pos = _projectStar(star);
      if (pos == null) continue;
      if (!_isNearVisibleBounds(pos)) continue;

      // Radius inversely proportional to magnitude (brighter = larger)
      final radius = _renderRadiusForStar(star);

      // Opacity scales from 0.5 at the minimum radius (0.5) up to 1.0 at
      // the maximum radius (8.0), so faint/small stars appear translucent.
      final opacity = (0.5 + (radius - 0.5) / 15.0).clamp(0.5, 1.0);

      final color = _colorFromBV(star.colorIdx ?? 0.6);

      // Glow
      canvas.drawCircle(
        pos,
        radius * 2.2,
        Paint()
          ..color = color.withAlpha((40 * opacity).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Core
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
  }

  // colorIdx (B-V): < -0.3 = O/B (blue), ~0.0 = A (white), ~0.3 = F (yellow-white),
  // ~0.6 = G (yellow), ~1.0 = K (orange), > 1.3 = M (red)
  Color _colorFromBV(double bv) {
    if (bv < -0.2) return const Color(0xFFADD8FF);
    if (bv < 0.1) return Colors.white;
    if (bv < 0.4) return const Color(0xFFFFF4E8);
    if (bv < 0.7) return const Color(0xFFFFE788);
    if (bv < 1.1) return const Color(0xFFFFB347);
    return const Color(0xFFFF6347);
  }

  // ---------------------------------------------------------------------------
  // Label rendering
  // ---------------------------------------------------------------------------

  /// Measures the layout width of [text] at [fontSize].
  double _textWidth(String text, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  /// Resolves the display name for [star] based on [showChineseName].
  /// Returns `null` if the resolved name is a raw HIP identifier.
  String? _starLabel(Star star) {
    final label = showChineseName ? (star.chineseName ?? star.name) : star.name;
    if (_hipRegex.hasMatch(label)) return null;
    return label;
  }

  /// Tries to place a label near [starPos] in one of 4 candidate positions,
  /// picking the first that does not overlap any rect in [placedRects].
  ///
  /// Returns `(textTopLeft, boundingRect)` on success.
  /// For forced labels (Group 1 / 2) falls back to position 1 on full overlap.
  /// For Group 3 labels returns `null` when no free position exists.
  (Offset, Rect)? _tryPlace({
    required Offset starPos,
    required double textWidth,
    required double fontSize,
    required List<Rect> placedRects,
    required bool forced,
  }) {
    final textH = fontSize + _labelTextHeightExtra;
    final rectW = textWidth + _labelPadding * 2;
    final rectH = textH + _labelPadding * 2;

    // 4 candidate text top-left positions
    final candidates = [
      Offset(
        starPos.dx + _labelHorizontalOffset,
        starPos.dy - fontSize - _labelVerticalOffset,
      ), // right-upper
      Offset(
        starPos.dx - textWidth - _labelHorizontalOffset,
        starPos.dy - fontSize - _labelVerticalOffset,
      ), // left-upper
      Offset(
        starPos.dx + _labelHorizontalOffset,
        starPos.dy + _labelVerticalOffset,
      ), // right-lower
      Offset(
        starPos.dx - textWidth - _labelHorizontalOffset,
        starPos.dy + _labelVerticalOffset,
      ), // left-lower
    ];

    for (final tl in candidates) {
      final rect = Rect.fromLTWH(
        tl.dx - _labelPadding,
        tl.dy - _labelPadding,
        rectW,
        rectH,
      );
      if (!placedRects.any((r) => r.overlaps(rect))) {
        return (tl, rect);
      }
    }

    // All positions overlap
    if (forced) {
      // Use position 1 (right-upper) as last-resort fallback
      final tl = candidates[0];
      final rect = Rect.fromLTWH(
        tl.dx - _labelPadding,
        tl.dy - _labelPadding,
        rectW,
        rectH,
      );
      return (tl, rect);
    }
    return null; // Group 3: skip
  }

  /// Computes the average screen position of the visible member stars of
  /// [constellation]. Returns `null` if no member star is in the viewport.
  Offset? _constellationCenter(
    Constellation constellation,
    Map<String, Star> starMap,
  ) {
    double sumX = 0, sumY = 0;
    int count = 0;
    for (final id in constellation.starIds) {
      final star = starMap[id];
      if (star == null) continue;
      final pos = _projectStar(star);
      if (pos == null) continue;
      sumX += pos.dx;
      sumY += pos.dy;
      count++;
    }
    if (count == 0) return null;
    return Offset(sumX / count, sumY / count);
  }

  /// Builds the full list of [_LabelSpec]s for the current viewport, running
  /// the greedy placement algorithm.  The result is cached in
  /// [_cachedLabelSpecs] and reused until the next repaint.
  List<_LabelSpec> _buildLabelSpecs() {
    if (_cachedLabelSpecs != null) return _cachedLabelSpecs!;

    final starMap = <String, Star>{for (final s in stars) s.id: s};

    // Determine which constellations drive Group-2 labels.
    final group2Constellations =
        showChineseName ? chineseConstellations : constellations;

    // Same threshold used in _drawStars: at low zoom only bright star names
    // are shown, preventing label explosion when many constellations are visible.
    final magThreshold = (2.5 + viewport.zoom * 2.0).clamp(3.0, 6.5);

    final placedRects = <Rect>[];
    final specs = <_LabelSpec>[];
    final minLabelRadius = _labelRadiusThreshold();
    const majorLabelMagnitudeThreshold = 2.5;

    // Helper: attempt to place a forced (Group 1 / 2) label and add it.
    void addForced(Offset starPos, String text, double fontSize, Color color) {
      final w = _textWidth(text, fontSize);
      final result = _tryPlace(
        starPos: starPos,
        textWidth: w,
        fontSize: fontSize,
        placedRects: placedRects,
        forced: true,
      );
      if (result != null) {
        final (tl, rect) = result;
        placedRects.add(rect);
        specs.add(
          _LabelSpec(
            textPos: tl,
            rect: rect,
            text: text,
            fontSize: fontSize,
            color: color,
          ),
        );
      }
    }

    // ── Group 1: Important celestial objects (always render) ──────────────
    final importantStarIds = <String>{};
    for (final star in stars) {
      final isImportant = _importantNames.contains(star.name) ||
          _importantNames.contains(star.chineseName);
      if (!isImportant) continue;
      final pos = _projectStar(star);
      if (pos == null) continue;
      final label =
          showChineseName ? (star.chineseName ?? star.name) : star.name;
      addForced(pos, label, 12.0, const Color(0xFFFFD700));
      importantStarIds.add(star.id);
    }

    // ── Group 2: Constellation / asterism names + member star names ───────
    final constellationColor = Colors.blueGrey.shade200.withAlpha(200);
    final memberStarColor = Colors.white.withAlpha(180);

    // Track which member stars have already been labeled to avoid duplicates
    // when the same star appears in multiple constellations.
    final labeledMemberIds = <String>{};

    for (final constellation in group2Constellations) {
      // Constellation / asterism name label
      final nameLabel = showChineseName
          ? (constellation.chineseName ?? constellation.name)
          : constellation.name;

      final center = _constellationCenter(constellation, starMap);
      if (center != null) {
        addForced(center, nameLabel, 13.0, constellationColor);
      }

      // Member star proper names
      for (final id in constellation.starIds) {
        if (labeledMemberIds.contains(id)) continue;
        final star = starMap[id];
        if (star == null) continue;
        // Cull faint member-star labels at low zoom; constellation names
        // above still render, but individual star names thin out to prevent
        // the label explosion caused by many constellations being on-screen.
        if (star.magnitude > magThreshold) continue;
        if (majorStarsOnlyLabels &&
            star.magnitude > majorLabelMagnitudeThreshold) {
          continue;
        }
        if (_renderRadiusForStar(star) < minLabelRadius) continue;
        final label = _starLabel(star);
        if (label == null) continue;
        final pos = _projectStar(star);
        if (pos == null) continue;
        if (!_isNearVisibleBounds(pos)) continue;
        addForced(pos, label, 10.0, memberStarColor);
        labeledMemberIds.add(id);
      }
    }

    // ── Group 3: Competitive stars ────────────────────────────────────────
    if (majorStarsOnlyLabels) {
      _cachedLabelSpecs = specs;
      return specs;
    }

    // Collect stars in the viewport that are not Group-1 or Group-2 members
    // and have a proper name.  Stars list is already sorted by magnitude
    // ascending (brightest first = lowest value first).
    final competitionColor = Colors.white.withAlpha(140);
    int competitionCount = 0;

    for (final star in stars) {
      if (competitionCount >= _maxCompetitiveLabels) break;
      if (_labelMemberStarIds.contains(star.id)) continue;
      if (importantStarIds.contains(star.id)) continue;
      if (!_showNonMemberStars()) continue;
      if (_renderRadiusForStar(star) < minLabelRadius) continue;
      final label = _starLabel(star);
      if (label == null) continue;
      final pos = _projectStar(star);
      if (pos == null) continue;
      if (!_isNearVisibleBounds(pos)) continue;

      final w = _textWidth(label, 10.0);
      final result = _tryPlace(
        starPos: pos,
        textWidth: w,
        fontSize: 10.0,
        placedRects: placedRects,
        forced: false,
      );
      if (result != null) {
        final (tl, rect) = result;
        placedRects.add(rect);
        specs.add(
          _LabelSpec(
            textPos: tl,
            rect: rect,
            text: label,
            fontSize: 10.0,
            color: competitionColor,
          ),
        );
        competitionCount++;
      }
    }

    _cachedLabelSpecs = specs;
    return specs;
  }

  /// Renders all computed label specs onto [canvas].
  void _drawLabels(Canvas canvas, Size _) {
    final specs = _buildLabelSpecs();
    for (final spec in specs) {
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.left,
          maxLines: 1,
          ellipsis: '…',
        ),
      )
        ..pushStyle(
          ui.TextStyle(color: spec.color, fontSize: spec.fontSize),
        )
        ..addText(spec.text);

      final paragraph = pb.build()
        ..layout(ui.ParagraphConstraints(width: spec.rect.width));
      canvas.drawParagraph(paragraph, spec.textPos);
    }
  }
}
