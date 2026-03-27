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
}
