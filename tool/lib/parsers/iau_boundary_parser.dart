import 'dart:io';
import 'package:csv/csv.dart';
import 'models.dart';

/// Parses the IAU constellation boundary data.
///
/// Expected CSV format (one vertex per row, comma-separated):
///   ra_hours, dec_deg, abbr
///
/// Where `ra_hours` is Right Ascension in hours (0–24) and `dec_deg` is
/// Declination in degrees (−90–+90).  Each block of vertices for the same
/// IAU abbreviation forms a closed polygon.
///
/// The original boundary dataset is available from:
///   https://cdsarc.cds.unistra.fr/viz-bin/cat/VI/49
///
/// The boundaries use the B1875 epoch; for visualisation purposes the
/// epoch difference is acceptable and no precession correction is applied.
class IauBoundaryParser {
  IauBoundaryParser._();

  /// Parse [file] and return a map from IAU abbreviation →
  /// list of [BoundaryPointRecord]s (in vertex order).
  static Map<String, List<BoundaryPointRecord>> parse(File file) {
    final content = file.readAsStringSync();
    final rows = const CsvToListConverter(eol: '\n').convert(content);

    final result = <String, List<BoundaryPointRecord>>{};

    for (final row in rows) {
      if (row.length < 3) continue;

      final raHours = double.tryParse(row[0].toString().trim());
      final decDeg  = double.tryParse(row[1].toString().trim());
      final abbr    = row[2].toString().trim().toUpperCase();

      if (raHours == null || decDeg == null || abbr.isEmpty) continue;

      // Convert RA from hours to degrees.
      final raDeg = raHours * 15.0;

      result.putIfAbsent(abbr, () => []).add(
        BoundaryPointRecord.quantize(raDeg, decDeg),
      );
    }

    return result;
  }
}
