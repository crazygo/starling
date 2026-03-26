import 'package:flat_buffers/flat_buffers.dart' as fb;
import '../parsers/models.dart';
import '../../generated/stargazer_generated.dart';

/// Serialises Chinese sky-culture data into a `culture_chinese.bin`
/// FlatBuffers byte buffer.
class ChineseBuilder {
  ChineseBuilder._();

  /// Build and return the FlatBuffers bytes for a [ChineseCulture].
  static List<int> build(List<AsterismRecord> asterisms) {
    final fbBuilder = fb.Builder(deduplicateTables: false);

    // Finish all asterism sub-tables first.
    final asterismOffsets = asterisms.map((a) {
      return ChineseAsterismObjectBuilder(
        name:     a.name,
        nameEn:   a.nameEn,
        quadrant: a.quadrant,
        mansion:  a.mansion,
        edges:    a.edges
            .map((e) => Edge(fromHip: e.fromHip, toHip: e.toHip))
            .toList(growable: false),
      ).finish(fbBuilder);
    }).toList(growable: false);

    final asterismsVecOffset = fbBuilder.writeList(asterismOffsets);

    fbBuilder.startTable(1);
    fbBuilder.addOffset(0, asterismsVecOffset);
    final rootOffset = fbBuilder.endTable();

    fbBuilder.finish(rootOffset);
    return fbBuilder.buffer;
  }
}
