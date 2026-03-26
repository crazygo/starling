/// Intermediate data models used inside the pipeline.
///
/// These are plain Dart classes – NOT FlatBuffers-generated.  They hold
/// parsed data between the [parsers] and [builders] layers.

// ─────────────────────────────────────────────────────────────────────────
// Shared
// ─────────────────────────────────────────────────────────────────────────

/// A directed edge connecting two stars, identified by Hipparcos ID.
class EdgeRecord {
  final int fromHip;
  final int toHip;

  const EdgeRecord({required this.fromHip, required this.toHip});

  @override
  String toString() => 'Edge($fromHip→$toHip)';
}

// ─────────────────────────────────────────────────────────────────────────
// Physical star catalog
// ─────────────────────────────────────────────────────────────────────────

/// One star from the Hipparcos catalogue.
class StarRecord {
  final int    hip;       // Hipparcos catalogue number
  final double ra;        // Right Ascension, degrees (0–360)
  final double dec;       // Declination, degrees (−90–+90)
  final double mag;       // Visual magnitude (Vmag)
  final double colorIdx;  // B−V colour index
  final String? nameEn;   // Western proper name (null if unnamed)
  final String? nameZh;   // Chinese proper name (null if unnamed)

  const StarRecord({
    required this.hip,
    required this.ra,
    required this.dec,
    required this.mag,
    required this.colorIdx,
    this.nameEn,
    this.nameZh,
  });

  /// Return a copy with the given name fields set.
  ///
  /// Note: passing `null` here retains the existing value; there is no way
  /// to clear a name via this method.  This is intentional — in the pipeline
  /// names are only ever added, never removed.
  StarRecord copyWith({
    String? nameEn,
    String? nameZh,
  }) {
    return StarRecord(
      hip:      hip,
      ra:       ra,
      dec:      dec,
      mag:      mag,
      colorIdx: colorIdx,
      nameEn:   nameEn   ?? this.nameEn,
      nameZh:   nameZh   ?? this.nameZh,
    );
  }

  @override
  String toString() =>
      'Star(hip=$hip, ra=${ra.toStringAsFixed(3)}, '
      'dec=${dec.toStringAsFixed(3)}, mag=${mag.toStringAsFixed(2)})';
}

// ─────────────────────────────────────────────────────────────────────────
// Western / IAU constellation data
// ─────────────────────────────────────────────────────────────────────────

/// A quantised boundary point – coordinates encoded as uint16.
class BoundaryPointRecord {
  final int raQ;   // uint16: RA  0°–360°  mapped to 0–65535
  final int decQ;  // uint16: Dec −90°–+90° mapped to 0–65535

  const BoundaryPointRecord({required this.raQ, required this.decQ});

  /// Quantise floating-point sky coordinates to uint16 range.
  factory BoundaryPointRecord.quantize(double ra, double dec) {
    return BoundaryPointRecord(
      raQ:  (ra  / 360.0        * 65535.0).round().clamp(0, 65535),
      decQ: ((dec + 90.0) / 180.0 * 65535.0).round().clamp(0, 65535),
    );
  }
}

/// One IAU constellation with stick-figure edges and sky boundary polygon.
class ConstellationRecord {
  final String abbr;       // IAU 3-letter abbreviation, e.g. "ORI"
  final String nameEn;     // English name, e.g. "Orion"
  final String nameZh;     // Chinese name, e.g. "猎户座"
  final int    family;     // [ConstellationFamily] constant (see generated file)
  final List<EdgeRecord>          edges;
  final List<BoundaryPointRecord> boundary;

  const ConstellationRecord({
    required this.abbr,
    required this.nameEn,
    required this.nameZh,
    required this.family,
    required this.edges,
    required this.boundary,
  });

  /// Return a copy with the given fields replaced.
  ConstellationRecord copyWith({
    String? abbr,
    String? nameEn,
    String? nameZh,
    int? family,
    List<EdgeRecord>? edges,
    List<BoundaryPointRecord>? boundary,
  }) {
    return ConstellationRecord(
      abbr:     abbr     ?? this.abbr,
      nameEn:   nameEn   ?? this.nameEn,
      nameZh:   nameZh   ?? this.nameZh,
      family:   family   ?? this.family,
      edges:    edges    ?? this.edges,
      boundary: boundary ?? this.boundary,
    );
  }

  @override
  String toString() =>
      'Constellation($abbr, edges=${edges.length}, '
      'boundary=${boundary.length})';
}

// ─────────────────────────────────────────────────────────────────────────
// Chinese sky-culture data
// ─────────────────────────────────────────────────────────────────────────

/// One Chinese asterism (星官).
class AsterismRecord {
  final String name;      // Chinese characters, e.g. "天狼"
  final String nameEn;    // English transliteration, e.g. "Celestial Wolf"
  final int    quadrant;  // [Quadrant] constant
  final int    mansion;   // [Mansion] constant; 0 = None (Three Enclosures)
  final List<EdgeRecord> edges;

  const AsterismRecord({
    required this.name,
    required this.nameEn,
    required this.quadrant,
    required this.mansion,
    required this.edges,
  });

  @override
  String toString() =>
      'Asterism($name / $nameEn, edges=${edges.length})';
}
