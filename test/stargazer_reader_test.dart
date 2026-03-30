import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starling/data/stargazer_reader.dart';

ByteData _loadBin(String assetPath) {
  final bytes = File(assetPath).readAsBytesSync();
  return bytes.buffer.asByteData();
}

void main() {
  group('StarCatalogReader (catalog_base.bin)', () {
    late StarCatalogReader reader;

    setUpAll(() {
      final buf = _loadBin('assets/bin/catalog_base.bin');
      reader = StarCatalogReader(buf);
    });

    test('parses the expected number of stars', () {
      expect(reader.starCount, 8870);
    });

    test('first star has a positive HIP number', () {
      final star = reader.starAt(0);
      expect(star.hip, greaterThan(0));
    });

    test('all stars have RA in [0, 360)', () {
      for (int i = 0; i < reader.starCount; i++) {
        final s = reader.starAt(i);
        expect(
          s.ra,
          inExclusiveRange(-0.001, 360.0),
          reason: 'star $i RA=${s.ra}',
        );
      }
    });

    test('all stars have Dec in [-90, 90]', () {
      for (int i = 0; i < reader.starCount; i++) {
        final s = reader.starAt(i);
        expect(
          s.dec,
          inInclusiveRange(-90.0, 90.0),
          reason: 'star $i Dec=${s.dec}',
        );
      }
    });

    test('Sirius (HIP 32349) has correct approximate magnitude', () {
      final all = reader.readAll();
      final sirius = all.firstWhere((s) => s.hip == 32349);
      expect(sirius.mag, closeTo(-1.44, 0.1));
    });

    test('Sirius (HIP 32349) has proper name "Sirius"', () {
      final all = reader.readAll();
      final sirius = all.firstWhere((s) => s.hip == 32349);
      expect(sirius.nameEn, 'Sirius');
    });

    test('unnamed stars have null nameEn', () {
      // HIP 1 (faint star, well below mag 4.0) should have no proper name.
      final all = reader.readAll();
      final unnamed = all.where((s) => s.nameEn == null);
      expect(
        unnamed.length,
        greaterThan(8000),
        reason: 'Most stars should have no proper name',
      );
    });

    test('Vega (HIP 91262) has correct approximate RA', () {
      final all = reader.readAll();
      final vega = all.firstWhere((s) => s.hip == 91262);
      // Vega RA ≈ 279.2°
      expect(vega.ra, closeTo(279.2, 1.0));
    });
  });

  group('WesternCultureReader (culture_western.bin)', () {
    late WesternCultureReader reader;

    setUpAll(() {
      final buf = _loadBin('assets/bin/culture_western.bin');
      reader = WesternCultureReader(buf);
    });

    test('parses 88 IAU constellations', () {
      expect(reader.constellationCount, 88);
    });

    test('constellation names are non-empty strings', () {
      for (int i = 0; i < reader.constellationCount; i++) {
        final c = reader.constellationAt(i);
        expect(c.abbr, isNotEmpty, reason: 'constellation $i abbr is empty');
        expect(c.nameEn, isNotEmpty, reason: 'constellation $i nameEn empty');
        expect(c.nameZh, isNotEmpty, reason: 'constellation $i nameZh empty');
      }
    });

    test('Chinese names are valid UTF-8 (contain CJK characters)', () {
      // All 88 IAU constellations have Chinese names ending in 座
      final all = reader.readAll();
      for (final c in all) {
        expect(
          c.nameZh.codeUnits.any((u) => u > 127),
          isTrue,
          reason: '${c.abbr} nameZh "${c.nameZh}" has no multibyte chars',
        );
      }
    });

    test('edges come in pairs (even count)', () {
      for (int i = 0; i < reader.constellationCount; i++) {
        final c = reader.constellationAt(i);
        expect(
          c.edges.length % 2,
          0,
          reason: '${c.abbr} has odd edge count ${c.edges.length}',
        );
      }
    });

    test('Aquila (AQL) has expected abbreviation and English name', () {
      final all = reader.readAll();
      final aql = all.firstWhere((c) => c.abbr == 'AQL');
      expect(aql.nameEn, 'Aquila');
      expect(aql.nameZh, '天鹰座');
    });

    test('all edge HIP values are positive', () {
      for (int i = 0; i < reader.constellationCount; i++) {
        final c = reader.constellationAt(i);
        for (final hip in c.edges) {
          expect(
            hip,
            greaterThan(0),
            reason: '${c.abbr} has zero HIP in edges',
          );
        }
      }
    });
  });

  group('WesternCultureReader (culture_chinese_modern.bin)', () {
    late WesternCultureReader reader;

    setUpAll(() {
      final buf = _loadBin('assets/bin/culture_chinese_modern.bin');
      reader = WesternCultureReader(buf);
    });

    test('parses 88 modern constellations', () {
      expect(reader.constellationCount, 88);
    });

    test('modern Chinese mode constellations expose Chinese names', () {
      final all = reader.readAll();
      final ori = all.firstWhere((c) => c.abbr == 'ORI');
      expect(ori.nameZh, isNotEmpty);
      expect(ori.nameZh.codeUnits.any((u) => u > 127), isTrue);
    });
  });

  group('ChineseCultureReader (culture_chinese.bin)', () {
    late ChineseCultureReader reader;

    setUpAll(() {
      final buf = _loadBin('assets/bin/culture_chinese.bin');
      reader = ChineseCultureReader(buf);
    });

    test('parses 318 Chinese asterisms', () {
      expect(reader.asterismCount, 318);
    });

    test('asterism names are non-empty', () {
      for (int i = 0; i < reader.asterismCount; i++) {
        final a = reader.asterismAt(i);
        expect(a.name, isNotEmpty, reason: 'asterism $i name is empty');
        expect(a.nameEn, isNotEmpty, reason: 'asterism $i nameEn is empty');
      }
    });

    test('Chinese names are valid UTF-8 (contain CJK characters)', () {
      final all = reader.readAll();
      for (final a in all) {
        expect(
          a.name.codeUnits.any((u) => u > 127),
          isTrue,
          reason: 'asterism "${a.name}" has no multibyte chars',
        );
      }
    });

    test('edges come in pairs (even count)', () {
      for (int i = 0; i < reader.asterismCount; i++) {
        final a = reader.asterismAt(i);
        expect(
          a.edges.length % 2,
          0,
          reason: '${a.name} has odd edge count ${a.edges.length}',
        );
      }
    });

    // ── Four Advisors (四辅) provenance tests ─────────────────────────────
    // The asterism whose connections the user observed:
    //   HIP 51384  ←→  HIP 51502  ←→  HIP 58874
    //
    // Raw source: constellationship.fab line 200
    //   200 2 58874 51502 51502 51384
    //
    // See docs/chinese-skyculture-hip-links.md for the full investigation.

    late BinChineseAsterism sifu;

    setUpAll(() {
      final all = reader.readAll();
      sifu = all.firstWhere(
        (a) => a.name == '四辅' || a.nameEn == 'Four Advisors',
        orElse: () => throw StateError('Four Advisors asterism not found'),
      );
    });

    test(
      'Four Advisors (四辅) asterism has correct Chinese and English names',
      () {
        expect(sifu.name, '四辅', reason: 'Chinese name should be 四辅');
        expect(
          sifu.nameEn,
          'Four Advisors',
          reason: 'English name should be Four Advisors',
        );
      },
    );

    test('Four Advisors (四辅) asterism contains exactly 2 edge pairs', () {
      // 2 pairs = 4 interleaved uint16 values
      expect(
        sifu.edges.length,
        4,
        reason: 'Expected 2 pairs (4 values) in Four Advisors edges',
      );
    });

    test(
      'Four Advisors (四辅) edge pairs are HIP 58874↔51502 and HIP 51502↔51384',
      () {
        final edges = sifu.edges;
        // Raw source line: 200 2 58874 51502 51502 51384
        // Expected interleaved pairs: [58874, 51502, 51502, 51384]
        expect(edges[0], 58874, reason: 'edge[0] should be HIP 58874 (from)');
        expect(edges[1], 51502, reason: 'edge[1] should be HIP 51502 (to)');
        expect(edges[2], 51502, reason: 'edge[2] should be HIP 51502 (from)');
        expect(edges[3], 51384, reason: 'edge[3] should be HIP 51384 (to)');
      },
    );

    test('Four Advisors (四辅) edges contain all three expected HIPs', () {
      final hipSet = sifu.edges.toSet();
      expect(
        hipSet,
        containsAll([51384, 51502, 58874]),
        reason: 'Four Advisors edges must include HIP 51384, 51502, and 58874',
      );
    });
  });
}
