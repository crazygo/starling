import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:starling/services/settings_service.dart';
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

    test('vertical pan is supported in dome mode', () {
      final nextDec = panCenterDecForStyle(
        ViewStyle.dome,
        baseCenterDec: 18.0,
        deltaDy: 120.0,
        degPerPxV: 0.15,
      );

      expect(nextDec, closeTo(36.0, epsilon));
    });

    test('vertical pan clamps in dome mode', () {
      final nextDec = panCenterDecForStyle(
        ViewStyle.dome,
        baseCenterDec: 85.0,
        deltaDy: 100.0,
        degPerPxV: 0.2,
      );

      expect(nextDec, closeTo(90.0, epsilon));
    });

    test('dome pan axis uses dominant direction', () {
      expect(
        domePanAxisFromDelta(const Offset(12, 3)),
        equals(Axis.horizontal),
      );
      expect(
        domePanAxisFromDelta(const Offset(2, -10)),
        equals(Axis.vertical),
      );
      expect(
        domePanAxisFromDelta(const Offset(1, 1)),
        isNull,
      );
    });
  });

  group('pan center dec behavior', () {
    test('classic mode still supports vertical pan with clamping', () {
      final nextDec = panCenterDecForStyle(
        ViewStyle.classic,
        baseCenterDec: 80.0,
        deltaDy: 100.0,
        degPerPxV: 0.2,
      );

      expect(nextDec, closeTo(90.0, epsilon));
    });
  });
}
