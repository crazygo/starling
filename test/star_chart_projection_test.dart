import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:starling/widgets/star_chart.dart';

void main() {
  const epsilon = 1e-9;

  group('classic star chart projection', () {
    test('uses fixed angular density at zoom 1', () {
      expect(classicDegreesPerPixelForZoom(1.0), closeTo(0.15, epsilon));
    });

    test('zoom increases angular density proportionally', () {
      expect(classicDegreesPerPixelForZoom(2.0), closeTo(0.075, epsilon));
      expect(classicDegreesPerPixelForZoom(0.5), closeTo(0.3, epsilon));
    });

    test('wider screens expose more horizontal sky at same zoom', () {
      final narrow = classicHalfSpanForSize(const Size(400, 800), 1.0);
      final wide = classicHalfSpanForSize(const Size(800, 800), 1.0);

      expect(narrow.dx, closeTo(30.0, epsilon));
      expect(wide.dx, closeTo(60.0, epsilon));
      expect(wide.dy, closeTo(narrow.dy, epsilon));
    });

    test('same density keeps horizontal and vertical scaling matched', () {
      final span = classicHalfSpanForSize(const Size(600, 400), 1.0);

      expect(span.dx / 300.0, closeTo(span.dy / 200.0, epsilon));
    });
  });

  group('dome star chart projection', () {
    test('uses fixed angular density at zoom 1', () {
      expect(domeDegreesPerPixelForZoom(1.0), closeTo(0.15, epsilon));
    });

    test('wider screens expose more horizontal sky at same zoom', () {
      final narrowFov = domeHorizontalFovForSize(const Size(400, 800), 1.0);
      final wideFov = domeHorizontalFovForSize(const Size(800, 800), 1.0);

      expect(wideFov, greaterThan(narrowFov));
    });

    test('taller screens expose more vertical sky at same zoom', () {
      final shortFov = domeVerticalFovForSize(const Size(800, 400), 1.0);
      final tallFov = domeVerticalFovForSize(const Size(800, 800), 1.0);

      expect(tallFov, greaterThan(shortFov));
    });
  });

  group('poleDeclinationArcs', () {
    test('northern hemisphere targets north pole', () {
      final arcs = poleDeclinationArcs(45.0);
      for (final (dec, _) in arcs) {
        expect(dec, greaterThan(50.0));
        expect(dec, lessThan(90.0));
      }
    });

    test('southern hemisphere targets south pole', () {
      final arcs = poleDeclinationArcs(-30.0);
      for (final (dec, _) in arcs) {
        expect(dec, lessThan(-50.0));
        expect(dec, greaterThan(-90.0));
      }
    });

    test('opacity decreases with distance from pole', () {
      final arcs = poleDeclinationArcs(45.0);
      expect(arcs.length, greaterThan(1));
      for (var i = 1; i < arcs.length; i++) {
        expect(arcs[i].$2, lessThan(arcs[i - 1].$2));
      }
    });

    test('arcs below minOpacity are excluded', () {
      final arcs = poleDeclinationArcs(45.0, minOpacity: 0.5);
      for (final (_, opacity) in arcs) {
        expect(opacity, greaterThanOrEqualTo(0.5));
      }
    });

    test('returns empty when minPoleDistanceDeg exceeds max', () {
      final arcs = poleDeclinationArcs(
        45.0,
        minPoleDistanceDeg: 40.0,
        maxPoleDistanceDeg: 35.0,
      );
      expect(arcs, isEmpty);
    });

    test('equator observer targets north pole (latitude >= 0)', () {
      final arcs = poleDeclinationArcs(0.0);
      for (final (dec, _) in arcs) {
        expect(dec, greaterThan(50.0));
      }
    });

    test('just-south observer targets south pole', () {
      final arcs = poleDeclinationArcs(-0.1);
      for (final (dec, _) in arcs) {
        expect(dec, lessThan(-50.0));
      }
    });
  });
}
