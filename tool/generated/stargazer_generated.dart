// GENERATED CODE – DO NOT MODIFY BY HAND
//
// This file is normally produced by:
//   flatc --dart -o generated/ schema/stargazer.fbs
//
// It has been manually authored to match schema/stargazer.fbs and checked
// into version control so that the pipeline can run without requiring a
// local flatc installation.  Re-generate whenever the schema changes.

// ignore_for_file: unused_import, camel_case_types, non_constant_identifier_names

import 'dart:typed_data';
import 'package:flat_buffers/flat_buffers.dart' as fb;

// ─────────────────────────────────────────────────────────────────────────
// Enumerations
// ─────────────────────────────────────────────────────────────────────────

/// IAU constellation family.
class ConstellationFamily {
  static const int zodiac   = 0;
  static const int ursa     = 1;
  static const int perseus  = 2;
  static const int hercules = 3;
  static const int orion    = 4;
  static const int heavenly = 5;
  static const int bayer    = 6;
  static const int laCaille = 7;
  static const int other    = 8;
}

/// Chinese sky quadrant (cardinal palace / Three Enclosures).
class Quadrant {
  static const int eastAzure    = 0;
  static const int northBlack   = 1;
  static const int westWhite    = 2;
  static const int southScarlet = 3;
  static const int central      = 4;
}

/// 28 lunar mansions; 0 = None (Three Enclosures).
class Mansion {
  static const int none        = 0;
  static const int horn        = 1;
  static const int neck        = 2;
  static const int root        = 3;
  static const int room        = 4;
  static const int heart       = 5;
  static const int tail        = 6;
  static const int winnowing   = 7;
  static const int dipper      = 8;
  static const int ox          = 9;
  static const int girl        = 10;
  static const int emptiness   = 11;
  static const int rooftop     = 12;
  static const int encampment  = 13;
  static const int wall        = 14;
  static const int stride      = 15;
  static const int bond        = 16;
  static const int stomach     = 17;
  static const int hairy       = 18;
  static const int net         = 19;
  static const int turtle      = 20;
  static const int three       = 21;
  static const int well        = 22;
  static const int ghost       = 23;
  static const int willow      = 24;
  static const int star        = 25;
  static const int extended    = 26;
  static const int wings       = 27;
  static const int chariot     = 28;
}

// ─────────────────────────────────────────────────────────────────────────
// Struct value objects (Dart-side, not FlatBuffers structs)
// ─────────────────────────────────────────────────────────────────────────

/// A directed edge connecting two stars by Hipparcos catalogue ID.
///
/// Serialised as two consecutive uint16 values inside a [uint16] vector:
///   [fromHip₀, toHip₀, fromHip₁, toHip₁, …]
class Edge {
  final int fromHip;
  final int toHip;
  const Edge({required this.fromHip, required this.toHip});
}

/// A quantised sky-coordinate point on a constellation boundary.
///
/// Serialised as two consecutive uint16 values inside a [uint16] vector:
///   [raQ₀, decQ₀, raQ₁, decQ₁, …]
class BoundaryPoint {
  final int raQ;
  final int decQ;
  const BoundaryPoint({required this.raQ, required this.decQ});

  /// Quantise floating-point sky coordinates to uint16 range.
  factory BoundaryPoint.quantize(double ra, double dec) {
    return BoundaryPoint(
      raQ:  (ra  / 360.0       * 65535.0).round().clamp(0, 65535),
      decQ: ((dec + 90.0) / 180.0 * 65535.0).round().clamp(0, 65535),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// catalog_base.bin  (root_type StarCatalog)
// ─────────────────────────────────────────────────────────────────────────

/// ObjectBuilder for the `Star` table.
class StarObjectBuilder extends fb.ObjectBuilder {
  final int    hip;
  final double ra;
  final double dec;
  final double mag;
  final double colorIdx;

  StarObjectBuilder({
    required this.hip,
    required this.ra,
    required this.dec,
    required this.mag,
    required this.colorIdx,
  });

  @override
  int finish(fb.Builder fbBuilder) {
    fbBuilder.startTable(5);
    fbBuilder.addUint32(0, hip);
    fbBuilder.addFloat32(1, ra);
    fbBuilder.addFloat32(2, dec);
    fbBuilder.addFloat32(3, mag);
    fbBuilder.addFloat32(4, colorIdx);
    return fbBuilder.endTable();
  }

  @override
  Uint8List toBytes([String? fileIdentifier]) {
    final fbBuilder = fb.Builder(deduplicateTables: false);
    fbBuilder.finish(finish(fbBuilder), fileIdentifier);
    return fbBuilder.buffer;
  }
}

/// ObjectBuilder for the `StarCatalog` table.
class StarCatalogObjectBuilder extends fb.ObjectBuilder {
  final List<StarObjectBuilder> stars;

  StarCatalogObjectBuilder({required this.stars});

  @override
  int finish(fb.Builder fbBuilder) {
    final starOffsets =
        stars.map((s) => s.finish(fbBuilder)).toList(growable: false);
    final starsOffset = fbBuilder.writeList(starOffsets);
    fbBuilder.startTable(1);
    fbBuilder.addOffset(0, starsOffset);
    return fbBuilder.endTable();
  }

  @override
  Uint8List toBytes([String? fileIdentifier]) {
    final fbBuilder = fb.Builder(deduplicateTables: false);
    fbBuilder.finish(finish(fbBuilder), fileIdentifier);
    return fbBuilder.buffer;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// culture_western.bin  (root_type WesternCulture)
// ─────────────────────────────────────────────────────────────────────────

/// ObjectBuilder for the `WesternConstellation` table.
class WesternConstellationObjectBuilder extends fb.ObjectBuilder {
  final String abbr;
  final String nameEn;
  final String nameZh;
  final int    family;   // ConstellationFamily constant
  final List<Edge> edges;
  final List<BoundaryPoint> boundary;

  WesternConstellationObjectBuilder({
    required this.abbr,
    required this.nameEn,
    required this.nameZh,
    required this.family,
    required this.edges,
    required this.boundary,
  });

  @override
  int finish(fb.Builder fbBuilder) {
    // Strings must be written before startTable.
    final abbrOffset   = fbBuilder.writeString(abbr);
    final nameEnOffset = fbBuilder.writeString(nameEn);
    final nameZhOffset = fbBuilder.writeString(nameZh);

    // Edge vector: interleaved uint16 pairs [fromHip, toHip, …].
    final edgeData = <int>[];
    for (final e in edges) {
      edgeData..add(e.fromHip)..add(e.toHip);
    }
    final edgesOffset = fbBuilder.writeListUint16(edgeData);

    // Boundary vector: interleaved uint16 pairs [raQ, decQ, …].
    final bpData = <int>[];
    for (final bp in boundary) {
      bpData..add(bp.raQ)..add(bp.decQ);
    }
    final boundaryOffset = fbBuilder.writeListUint16(bpData);

    fbBuilder.startTable(6);
    fbBuilder.addOffset(0, abbrOffset);
    fbBuilder.addOffset(1, nameEnOffset);
    fbBuilder.addOffset(2, nameZhOffset);
    fbBuilder.addUint8(3, family);
    fbBuilder.addOffset(4, edgesOffset);
    fbBuilder.addOffset(5, boundaryOffset);
    return fbBuilder.endTable();
  }

  @override
  Uint8List toBytes([String? fileIdentifier]) {
    final fbBuilder = fb.Builder(deduplicateTables: false);
    fbBuilder.finish(finish(fbBuilder), fileIdentifier);
    return fbBuilder.buffer;
  }
}

/// ObjectBuilder for the `WesternCulture` table.
class WesternCultureObjectBuilder extends fb.ObjectBuilder {
  final List<WesternConstellationObjectBuilder> constellations;

  WesternCultureObjectBuilder({required this.constellations});

  @override
  int finish(fb.Builder fbBuilder) {
    final offsets = constellations
        .map((c) => c.finish(fbBuilder))
        .toList(growable: false);
    final consOffset = fbBuilder.writeList(offsets);
    fbBuilder.startTable(1);
    fbBuilder.addOffset(0, consOffset);
    return fbBuilder.endTable();
  }

  @override
  Uint8List toBytes([String? fileIdentifier]) {
    final fbBuilder = fb.Builder(deduplicateTables: false);
    fbBuilder.finish(finish(fbBuilder), fileIdentifier);
    return fbBuilder.buffer;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// culture_chinese.bin  (root_type ChineseCulture)
// ─────────────────────────────────────────────────────────────────────────

/// ObjectBuilder for the `ChineseAsterism` table.
class ChineseAsterismObjectBuilder extends fb.ObjectBuilder {
  final String    name;
  final String    nameEn;
  final int       quadrant;  // Quadrant constant
  final int       mansion;   // Mansion constant
  final List<Edge> edges;

  ChineseAsterismObjectBuilder({
    required this.name,
    required this.nameEn,
    required this.quadrant,
    required this.mansion,
    required this.edges,
  });

  @override
  int finish(fb.Builder fbBuilder) {
    final nameOffset   = fbBuilder.writeString(name);
    final nameEnOffset = fbBuilder.writeString(nameEn);

    final edgeData = <int>[];
    for (final e in edges) {
      edgeData..add(e.fromHip)..add(e.toHip);
    }
    final edgesOffset = fbBuilder.writeListUint16(edgeData);

    fbBuilder.startTable(5);
    fbBuilder.addOffset(0, nameOffset);
    fbBuilder.addOffset(1, nameEnOffset);
    fbBuilder.addUint8(2, quadrant);
    fbBuilder.addUint8(3, mansion);
    fbBuilder.addOffset(4, edgesOffset);
    return fbBuilder.endTable();
  }

  @override
  Uint8List toBytes([String? fileIdentifier]) {
    final fbBuilder = fb.Builder(deduplicateTables: false);
    fbBuilder.finish(finish(fbBuilder), fileIdentifier);
    return fbBuilder.buffer;
  }
}

/// ObjectBuilder for the `ChineseCulture` table.
class ChineseCultureObjectBuilder extends fb.ObjectBuilder {
  final List<ChineseAsterismObjectBuilder> asterisms;

  ChineseCultureObjectBuilder({required this.asterisms});

  @override
  int finish(fb.Builder fbBuilder) {
    final offsets = asterisms
        .map((a) => a.finish(fbBuilder))
        .toList(growable: false);
    final asterismsOffset = fbBuilder.writeList(offsets);
    fbBuilder.startTable(1);
    fbBuilder.addOffset(0, asterismsOffset);
    return fbBuilder.endTable();
  }

  @override
  Uint8List toBytes([String? fileIdentifier]) {
    final fbBuilder = fb.Builder(deduplicateTables: false);
    fbBuilder.finish(finish(fbBuilder), fileIdentifier);
    return fbBuilder.buffer;
  }
}
