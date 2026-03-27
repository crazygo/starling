import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/star.dart';
import '../models/constellation.dart';
import '../services/settings_service.dart';

const double _domeMinCenterDec = -70.0;
const double _domeMaxCenterDec = 62.0;
const double _domeCapStart = 54.0;
const double _domeTopSafeFraction = 0.14;
const double _domeBottomSafeFraction = 0.96;
const double _domeDefaultCenterDec = 45.0;
const double _domeGuideBaseFraction = 0.74;

double _softClampDomeDec(double dec) {
  if (dec > _domeCapStart) {
    final overshoot = dec - _domeCapStart;
    final damped = overshoot / (1 + overshoot / 8);
    dec = _domeCapStart + damped;
  }
  return dec.clamp(_domeMinCenterDec, _domeMaxCenterDec).toDouble();
}

double _effectiveCenterDecForStyle(
  ViewStyle viewStyle,
  double baseCenterDec,
  double gyroDec,
) {
  final effectiveDec = baseCenterDec + gyroDec;
  if (viewStyle == ViewStyle.dome) {
    return _softClampDomeDec(effectiveDec);
  }
  return effectiveDec.clamp(-90.0, 90.0).toDouble();
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
    double newDec = base.centerDec + delta.dy * degPerPxV;
    newDec = widget.viewStyle == ViewStyle.dome
        ? _softClampDomeDec(newDec)
        : newDec.clamp(-90.0, 90.0);

    // Zoom
    final newZoom = (base.zoom * d.scale).clamp(0.3, 10.0);

    widget.onViewportChanged(
      base.copyWith(centerRa: newRa, centerDec: newDec, zoom: newZoom),
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Two-finger trackpad scroll → pan
      final vp = widget.viewport;
      final size = context.size ?? const Size(400, 800);
      final degPerPxH = (120.0 / vp.zoom) / size.width;
      final degPerPxV = (60.0 / vp.zoom) / size.height;

      double newRa = (vp.centerRa + event.scrollDelta.dx * degPerPxH) % 360.0;
      if (newRa < 0) newRa += 360.0;
      final rawDec = vp.centerDec - event.scrollDelta.dy * degPerPxV;
      final newDec = widget.viewStyle == ViewStyle.dome
          ? _softClampDomeDec(rawDec)
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
    final vp = widget.viewport;
    final gyro = widget.gyroOffset;

    final effectiveRa = (vp.centerRa + (gyro?.dx ?? 0)) % 360.0;
    final effectiveDec = _effectiveCenterDecForStyle(
      widget.viewStyle,
      vp.centerDec,
      gyro?.dy ?? 0,
    );

    final halfW = (60.0 / vp.zoom); // degrees
    final halfH = (30.0 / vp.zoom);

    double dRa = star.rightAscension - effectiveRa;
    // Wrap RA difference to [-180, 180]
    if (dRa > 180) dRa -= 360;
    if (dRa < -180) dRa += 360;
    final dDec = star.declination - effectiveDec;

    if (dRa.abs() > halfW || dDec.abs() > halfH) return null;

    final px = (size.width / 2) + (dRa / halfW) * (size.width / 2);
    final linearPy = (size.height / 2) - (dDec / halfH) * (size.height / 2);
    final projected = widget.viewStyle == ViewStyle.dome
        ? Offset(px, _mapDomeY(linearPy, size))
        : Offset(px, linearPy);
    return projected;
  }

  double _mapDomeY(double linearPy, Size size) {
    final normalized = linearPy / size.height;
    return ui.lerpDouble(
      size.height * _domeTopSafeFraction,
      size.height * _domeBottomSafeFraction,
      normalized,
    )!;
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
      old.size != size;

  Offset? _project(double raDeg, double decDeg) {
    final vp = viewport;
    final gyro = gyroOffset;

    final effectiveRa = (vp.centerRa + (gyro?.dx ?? 0)) % 360.0;
    final effectiveDec = _effectiveCenterDecForStyle(
      viewStyle,
      vp.centerDec,
      gyro?.dy ?? 0,
    );

    final halfW = 60.0 / vp.zoom;
    final halfH = 30.0 / vp.zoom;

    double dRa = raDeg - effectiveRa;
    if (dRa > 180) dRa -= 360;
    if (dRa < -180) dRa += 360;
    final dDec = decDeg - effectiveDec;

    if (dRa.abs() > halfW * 1.1 || dDec.abs() > halfH * 1.1) return null;

    final px = (size.width / 2) + (dRa / halfW) * (size.width / 2);
    final linearPy = (size.height / 2) - (dDec / halfH) * (size.height / 2);
    final projected = viewStyle == ViewStyle.dome
        ? Offset(px, _mapDomeY(linearPy))
        : Offset(px, linearPy);
    return projected;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackdrop(canvas, size);

    if (viewStyle == ViewStyle.dome) {
      _drawBackgroundStars(canvas, size);
      _drawConstellationLines(canvas);
      _drawStars(canvas, _constellationMemberStarIds);
      _drawLabels(canvas, size);
      _drawDomeForeground(canvas, size);
      return;
    }

    _drawBackgroundStars(canvas, size);
    _drawConstellationLines(canvas);
    _drawStars(canvas, _constellationMemberStarIds);
    _drawLabels(canvas, size);
  }

  double _mapDomeY(double linearPy) {
    final normalized = linearPy / size.height;
    return ui.lerpDouble(
      size.height * _domeTopSafeFraction,
      size.height * _domeBottomSafeFraction,
      normalized,
    )!;
  }

  double _guideLinearPy(double effectiveDec) {
    final halfH = 30.0 / viewport.zoom;
    const baseLinearFraction =
        (_domeGuideBaseFraction - _domeTopSafeFraction) /
        (_domeBottomSafeFraction - _domeTopSafeFraction);
    final baseLinearPy = size.height * baseLinearFraction;
    final linearShift =
        ((effectiveDec - _domeDefaultCenterDec) / halfH) * (size.height / 2);
    return baseLinearPy + linearShift;
  }

  void _drawBackdrop(Canvas canvas, Size size) {
    if (viewStyle == ViewStyle.classic) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF05091A),
      );
      return;
    }

    final effectiveDec = _effectiveCenterDecForStyle(
      viewStyle,
      viewport.centerDec,
      gyroOffset?.dy ?? 0,
    );
    final horizonY = _mapDomeY(_guideLinearPy(effectiveDec)).clamp(
      -size.height,
      size.height * 2,
    );
    final fullRect = Offset.zero & size;
    canvas.drawRect(
      fullRect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, size.height),
          const [Color(0xFF020611), Color(0xFF07152A), Color(0xFF11263D)],
          const [0.0, 0.58, 1.0],
        ),
    );

    final lowerHemisphereTop = horizonY.clamp(0.0, size.height).toDouble();
    final lowerHemisphereRect = Rect.fromLTWH(
      0,
      lowerHemisphereTop,
      size.width,
      size.height - lowerHemisphereTop,
    );
    canvas.drawRect(
      lowerHemisphereRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, lowerHemisphereRect.top),
          Offset(0, lowerHemisphereRect.bottom),
          const [Color(0x121E3658), Color(0x22314658), Color(0x442A3446)],
        ),
    );
  }

  void _drawDomeForeground(Canvas canvas, Size size) {
    final effectiveDec = _effectiveCenterDecForStyle(
      viewStyle,
      viewport.centerDec,
      gyroOffset?.dy ?? 0,
    );
    final horizonY = _mapDomeY(_guideLinearPy(effectiveDec));
    final arcRect = Rect.fromCenter(
      center: Offset(size.width / 2, horizonY + size.height * 0.14),
      width: size.width * 1.9,
      height: size.height * 0.16,
    );
    final horizonGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0x33F7C78C)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final horizonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x55FFDDB3);
    canvas.drawArc(
      arcRect,
      pi,
      pi,
      false,
      horizonGlow,
    );
    canvas.drawArc(
      arcRect,
      pi,
      pi,
      false,
      horizonPaint,
    );

    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0x22FFE1B8),
    );

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

  void _drawStars(Canvas canvas, Set<String> activeMemberStarIds) {
    // Dynamic magnitude threshold: at low zoom (zoomed out) only brighter stars
    // are shown. Formula yields ~4.5 at zoom=1.0, ~6.5 (full catalogue) at
    // zoom>=2.0, and floors at 3.0 when very zoomed out. Member stars of the
    // active constellations are always shown so constellation lines stay intact.
    final magThreshold = (2.5 + viewport.zoom * 2.0).clamp(3.0, 6.5);

    for (final star in stars) {
      // Cull faint non-member stars when zoomed out.
      if (star.magnitude > magThreshold &&
          !activeMemberStarIds.contains(star.id)) {
        continue;
      }

      final pos = _project(star.rightAscension, star.declination);
      if (pos == null) continue;

      // Radius inversely proportional to magnitude (brighter = larger)
      final radius = ((6.5 - star.magnitude) * 0.9 * viewport.zoom).clamp(
        0.5,
        8.0,
      );

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
      final pos = _project(star.rightAscension, star.declination);
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
      final pos = _project(star.rightAscension, star.declination);
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
        final label = _starLabel(star);
        if (label == null) continue;
        final pos = _project(star.rightAscension, star.declination);
        if (pos == null) continue;
        addForced(pos, label, 10.0, memberStarColor);
        labeledMemberIds.add(id);
      }
    }

    // ── Group 3: Competitive stars ────────────────────────────────────────
    // Collect stars in the viewport that are not Group-1 or Group-2 members
    // and have a proper name.  Stars list is already sorted by magnitude
    // ascending (brightest first = lowest value first).
    final competitionColor = Colors.white.withAlpha(140);
    int competitionCount = 0;

    for (final star in stars) {
      if (competitionCount >= _maxCompetitiveLabels) break;
      if (_labelMemberStarIds.contains(star.id)) continue;
      if (importantStarIds.contains(star.id)) continue;
      final label = _starLabel(star);
      if (label == null) continue;
      final pos = _project(star.rightAscension, star.declination);
      if (pos == null) continue;

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
