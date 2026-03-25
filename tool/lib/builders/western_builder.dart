import 'package:flat_buffers/flat_buffers.dart' as fb;
import '../parsers/models.dart';
import '../../generated/stargazer_generated.dart';

/// Serialises IAU constellation data into a `culture_western.bin`
/// FlatBuffers byte buffer.
class WesternBuilder {
  WesternBuilder._();

  /// Build and return the FlatBuffers bytes for a [WesternCulture].
  ///
  /// [lines] is the map from IAU abbreviation → [ConstellationRecord] produced
  /// by [IauLinesParser].
  ///
  /// [boundaries] is the map from IAU abbreviation → boundary vertices
  /// produced by [IauBoundaryParser].  Missing boundary entries result in an
  /// empty boundary list for that constellation (not an error).
  static List<int> build(
    Map<String, ConstellationRecord> lines,
    Map<String, List<BoundaryPointRecord>> boundaries,
  ) {
    final fbBuilder = fb.Builder(deduplicateTables: false);

    // Finish all constellation sub-tables first.
    final conOffsets = lines.values.map((cons) {
      final boundary = boundaries[cons.abbr] ?? const [];

      return WesternConstellationObjectBuilder(
        abbr:     cons.abbr,
        nameEn:   cons.nameEn,
        nameZh:   cons.nameZh,
        family:   cons.family,
        edges:    cons.edges,
        boundary: boundary,
      ).finish(fbBuilder);
    }).toList(growable: false);

    final consVecOffset = fbBuilder.writeList(conOffsets);

    fbBuilder.startTable(1);
    fbBuilder.addOffset(0, consVecOffset);
    final rootOffset = fbBuilder.endTable();

    fbBuilder.finish(rootOffset);
    return fbBuilder.buffer;
  }
}
