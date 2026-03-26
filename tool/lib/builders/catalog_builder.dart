import 'package:flat_buffers/flat_buffers.dart' as fb;
import '../parsers/models.dart';
import '../../generated/stargazer_generated.dart';

/// Serialises a list of [StarRecord]s into a `catalog_base.bin`
/// FlatBuffers byte buffer.
class CatalogBuilder {
  CatalogBuilder._();

  /// Build and return the FlatBuffers bytes for a [StarCatalog].
  ///
  /// Stars are sorted by ascending HIP number before serialisation so that
  /// the Flutter reader can use binary search for O(log n) lookups.
  static List<int> build(List<StarRecord> stars) {
    // Sort by HIP number (ascending) for binary-search access on the read side.
    final sorted = List<StarRecord>.from(stars)
      ..sort((a, b) => a.hip.compareTo(b.hip));

    final fbBuilder = fb.Builder();

    // Finish all star sub-tables first (children before parent).
    final starOffsets = sorted
        .map((s) => StarObjectBuilder(
              hip:      s.hip,
              ra:       s.ra,
              dec:      s.dec,
              mag:      s.mag,
              colorIdx: s.colorIdx,
            ).finish(fbBuilder))
        .toList(growable: false);

    final starsVecOffset = fbBuilder.writeList(starOffsets);

    fbBuilder.startTable(1);
    fbBuilder.addOffset(0, starsVecOffset);
    final rootOffset = fbBuilder.endTable();

    fbBuilder.finish(rootOffset);
    return fbBuilder.buffer;
  }
}
