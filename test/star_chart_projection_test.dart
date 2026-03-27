import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:starling/widgets/star_chart.dart';

void main() {
  group('classic star chart projection', () {
    test('uses fixed angular density at zoom 1', () {
      expect(classicDegreesPerPixelForZoom(1.0), 0.15);
    });

    test('zoom increases angular density proportionally', () {
      expect(classicDegreesPerPixelForZoom(2.0), 0.075);
      expect(classicDegreesPerPixelForZoom(0.5), 0.3);
    });

    test('wider screens expose more horizontal sky at same zoom', () {
      final narrow = classicHalfSpanForSize(const Size(400, 800), 1.0);
      final wide = classicHalfSpanForSize(const Size(800, 800), 1.0);

      expect(narrow.dx, 30.0);
      expect(wide.dx, 60.0);
      expect(wide.dy, narrow.dy);
    });

    test('same density keeps horizontal and vertical scaling matched', () {
      final span = classicHalfSpanForSize(const Size(600, 400), 1.0);

      expect(span.dx / 300.0, span.dy / 200.0);
    });
  });

  group('dome star chart projection', () {
    test('uses fixed angular density at zoom 1', () {
      expect(domeDegreesPerPixelForZoom(1.0), 0.15);
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
