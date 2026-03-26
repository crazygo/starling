import 'dart:math';
import 'package:flutter/material.dart';
import '../models/star.dart';
import '../models/constellation.dart';

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
class StarChart extends StatefulWidget {
  final List<Star> stars;
  final List<Constellation> constellations;
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
    final size = context.size ?? const Size(400, 800);

    // Pan: translate focal-point delta to RA/Dec degrees
    final delta = d.localFocalPoint - _panStart!;
    final degPerPxH = (120.0 / base.zoom) / size.width;
    final degPerPxV = (60.0 / base.zoom) / size.height;

    double newRa = (base.centerRa - delta.dx * degPerPxH) % 360.0;
    if (newRa < 0) newRa += 360.0;
    double newDec = (base.centerDec + delta.dy * degPerPxV).clamp(-90.0, 90.0);

    // Zoom
    final newZoom = (base.zoom * d.scale).clamp(0.3, 10.0);

    widget.onViewportChanged(
      base.copyWith(centerRa: newRa, centerDec: newDec, zoom: newZoom),
    );
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
    final vp = widget.viewport;
    final gyro = widget.gyroOffset;

    final effectiveRa =
        (vp.centerRa + (gyro?.dx ?? 0)) % 360.0;
    final effectiveDec =
        (vp.centerDec + (gyro?.dy ?? 0)).clamp(-90.0, 90.0);

    final halfW = (60.0 / vp.zoom);  // degrees
    final halfH = (30.0 / vp.zoom);

    double dRa = star.rightAscension - effectiveRa;
    // Wrap RA difference to [-180, 180]
    if (dRa > 180) dRa -= 360;
    if (dRa < -180) dRa += 360;
    final dDec = star.declination - effectiveDec;

    if (dRa.abs() > halfW || dDec.abs() > halfH) return null;

    final px = (size.width / 2) + (dRa / halfW) * (size.width / 2);
    final py = (size.height / 2) - (dDec / halfH) * (size.height / 2);
    return Offset(px, py);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
              viewport: widget.viewport,
              gyroOffset: widget.gyroOffset,
              size: size,
            ),
            size: size,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _StarPainter extends CustomPainter {
  final List<Star> stars;
  final List<Constellation> constellations;
  final StarChartViewport viewport;
  final Offset? gyroOffset;
  final Size size;

  // Normalized [0, 1) background star positions precomputed once.
  // Using a fixed seed means the pattern is deterministic and stable.
  static final List<Offset> _bgStarPositions = _precomputeBgStars();

  static List<Offset> _precomputeBgStars() {
    final rng = Random(42);
    return List.generate(
      300,
      (_) => Offset(rng.nextDouble(), rng.nextDouble()),
    );
  }

  const _StarPainter({
    required this.stars,
    required this.constellations,
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
      old.size != size;

  Offset? _project(double raDeg, double decDeg) {
    final vp = viewport;
    final gyro = gyroOffset;

    final effectiveRa = (vp.centerRa + (gyro?.dx ?? 0)) % 360.0;
    final effectiveDec = (vp.centerDec + (gyro?.dy ?? 0)).clamp(-90.0, 90.0);

    final halfW = 60.0 / vp.zoom;
    final halfH = 30.0 / vp.zoom;

    double dRa = raDeg - effectiveRa;
    if (dRa > 180) dRa -= 360;
    if (dRa < -180) dRa += 360;
    final dDec = decDeg - effectiveDec;

    if (dRa.abs() > halfW * 1.1 || dDec.abs() > halfH * 1.1) return null;

    final px = (size.width / 2) + (dRa / halfW) * (size.width / 2);
    final py = (size.height / 2) - (dDec / halfH) * (size.height / 2);
    return Offset(px, py);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF05091A),
    );

    _drawBackgroundStars(canvas, size);
    _drawConstellationLines(canvas);
    _drawStars(canvas);
  }

  void _drawBackgroundStars(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withAlpha(77);
    for (final pos in _bgStarPositions) {
      canvas.drawCircle(
        Offset(pos.dx * size.width, pos.dy * size.height),
        0.5,
        paint,
      );
    }
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
        final p1 = _project(s1.rightAscension, s1.declination);
        final p2 = _project(s2.rightAscension, s2.declination);
        if (p1 == null || p2 == null) continue;
        canvas.drawLine(p1, p2, linePaint);
      }
    }
  }

  void _drawStars(Canvas canvas) {
    for (final star in stars) {
      final pos = _project(star.rightAscension, star.declination);
      if (pos == null) continue;

      // Radius inversely proportional to magnitude (brighter = larger)
      final radius = ((6.5 - star.magnitude) * 0.9 * viewport.zoom)
          .clamp(1.5, 8.0);

      final color = _colorFromBV(star.colorIdx ?? 0.6);

      // Glow
      canvas.drawCircle(
        pos,
        radius * 2.2,
        Paint()
          ..color = color.withAlpha(40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Core
      canvas.drawCircle(pos, radius, Paint()..color = color);
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
}
