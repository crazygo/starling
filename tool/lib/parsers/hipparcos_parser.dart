import 'dart:io';
import 'models.dart';

/// Parses the ESA Hipparcos main catalogue (hip_main.csv).
///
/// The Hipparcos catalogue uses a fixed-width text format.  The CSV copy
/// available from CDS (I/239) stores one star per line with fields separated
/// by the pipe character `|`.  The column indices below match that layout:
///
/// Field indices (0-based, pipe-separated):
///   1  – HIP number
///   5  – Visual magnitude (Vmag)
///   8  – Right Ascension (degrees, J2000)
///   9  – Declination     (degrees, J2000)
///   37 – B−V colour index
///
/// See: https://cdsarc.cds.unistra.fr/viz-bin/cat/I/239
class HipparcosParser {
  HipparcosParser._();

  /// Parse [file] and return stars with `mag ≤ [maxMagnitude]`.
  ///
  /// Lines that cannot be parsed (header, malformed) are silently skipped.
  static List<StarRecord> parse(
    File file, {
    double maxMagnitude = 6.5,
  }) {
    final lines = file.readAsLinesSync();
    final results = <StarRecord>[];

    for (final line in lines) {
      // The pipe-delimited format may have leading/trailing whitespace.
      final fields = line.split('|');
      if (fields.length < 38) continue;

      final hip      = int.tryParse(fields[1].trim());
      final mag      = double.tryParse(fields[5].trim());
      final ra       = double.tryParse(fields[8].trim());
      final dec      = double.tryParse(fields[9].trim());
      final colorIdx = double.tryParse(fields[37].trim()) ?? 0.0;

      if (hip == null || mag == null || ra == null || dec == null) continue;
      if (mag > maxMagnitude) continue;

      results.add(StarRecord(
        hip:      hip,
        ra:       ra,
        dec:      dec,
        mag:      mag,
        colorIdx: colorIdx,
      ));
    }

    return results;
  }
}
