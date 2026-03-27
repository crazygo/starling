import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starling/data/stargazer_reader.dart';

ByteData _loadBin(String assetPath) {
  final bytes = File(assetPath).readAsBytesSync();
  return bytes.buffer.asByteData();
}

bool _hasEdge(List<int> edges, int fromHip, int toHip) {
  for (int i = 0; i + 1 < edges.length; i += 2) {
    final a = edges[i];
    final b = edges[i + 1];
    if ((a == fromHip && b == toHip) || (a == toHip && b == fromHip)) {
      return true;
    }
  }
  return false;
}

void main() {
  group('western link regression', () {
    late WesternCultureReader reader;

    setUpAll(() {
      final buf = _loadBin('assets/bin/culture_western.bin');
      reader = WesternCultureReader(buf);
    });

    test('Sagittarius does not contain the invalid HIP 27319 ↔ 28328 link', () {
      final sgr = reader.readAll().firstWhere((c) => c.abbr == 'SGR');
      expect(_hasEdge(sgr.edges, 27319, 28328), isFalse);
    });

    test('Columba still contains the valid HIP 27628 ↔ 28328 link', () {
      final col = reader.readAll().firstWhere((c) => c.abbr == 'COL');
      expect(_hasEdge(col.edges, 27628, 28328), isTrue);
    });
  });

  test('Chinese culture no longer contains the invalid HIP 27319 ↔ 28328 link',
      () {
    final buf = _loadBin('assets/bin/culture_chinese.bin');
    final reader = ChineseCultureReader(buf);
    final hasInvalidLink = reader.readAll().any(
          (asterism) => _hasEdge(asterism.edges, 27319, 28328),
        );
    expect(hasInvalidLink, isFalse);
  });
}
