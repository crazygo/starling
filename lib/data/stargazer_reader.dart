import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Low-level FlatBuffers helpers
// ---------------------------------------------------------------------------

/// Read a uint32 (little-endian) at [offset] in [data].
int _readUint32(ByteData data, int offset) =>
    data.getUint32(offset, Endian.little);

/// Read a float32 (little-endian) at [offset] in [data].
double _readFloat32(ByteData data, int offset) =>
    data.getFloat32(offset, Endian.little);

/// Read a uint16 (little-endian) at [offset] in [data].
int _readUint16(ByteData data, int offset) =>
    data.getUint16(offset, Endian.little);

/// Read a uint8 at [offset] in [data].
int _readUint8(ByteData data, int offset) => data.getUint8(offset);

/// Read a FlatBuffers-encoded UTF-8 string whose length prefix starts at the
/// absolute byte position [strOffset] in [buf].
String _readString(ByteData buf, int strOffset) {
  final len = _readUint32(buf, strOffset);
  final bytes = Uint8List.view(
    buf.buffer,
    buf.offsetInBytes + strOffset + 4,
    len,
  );
  return String.fromCharCodes(bytes);
}

/// Follow the root-table offset encoded at the start of a FlatBuffers buffer.
/// Returns the absolute byte offset of the root table.
int _rootTableOffset(ByteData buf) {
  // The first 4 bytes store the forward offset to the root table.
  final fwdOffset = _readUint32(buf, 0);
  return fwdOffset; // already absolute from buffer start
}

/// Read a vtable field offset for the given [fieldIndex] inside [tableOffset].
/// Returns 0 if the field is absent.
int _fieldOffset(ByteData buf, int tableOffset, int fieldIndex) {
  // The vtable offset (signed int32, little-endian) is stored at tableOffset.
  final vtableRelOffset = buf.getInt32(tableOffset, Endian.little);
  final vtableOffset = tableOffset - vtableRelOffset;

  // vtable layout: [vtable_size:uint16, object_size:uint16, field0:uint16, ...]
  final vtableSize = _readUint16(buf, vtableOffset);
  final fieldPos = vtableOffset + 4 + fieldIndex * 2;
  if (fieldPos >= vtableOffset + vtableSize) return 0;
  final offset = _readUint16(buf, fieldPos);
  return offset; // relative to tableOffset; 0 means absent
}

/// Read a scalar uint8 field from a table. Returns [defaultValue] if absent.
int _tableUint8(ByteData buf, int tableOffset, int fieldIndex,
    [int defaultValue = 0]) {
  final rel = _fieldOffset(buf, tableOffset, fieldIndex);
  if (rel == 0) return defaultValue;
  return _readUint8(buf, tableOffset + rel);
}

/// Read a scalar uint32 field from a table. Returns [defaultValue] if absent.
int _tableUint32(ByteData buf, int tableOffset, int fieldIndex,
    [int defaultValue = 0]) {
  final rel = _fieldOffset(buf, tableOffset, fieldIndex);
  if (rel == 0) return defaultValue;
  return _readUint32(buf, tableOffset + rel);
}

/// Read a scalar float32 field from a table. Returns [defaultValue] if absent.
double _tableFloat32(ByteData buf, int tableOffset, int fieldIndex,
    [double defaultValue = 0.0]) {
  final rel = _fieldOffset(buf, tableOffset, fieldIndex);
  if (rel == 0) return defaultValue;
  return _readFloat32(buf, tableOffset + rel);
}

/// Follow an offset field and return its absolute position, or null if absent.
int? _tableOffsetField(ByteData buf, int tableOffset, int fieldIndex) {
  final rel = _fieldOffset(buf, tableOffset, fieldIndex);
  if (rel == 0) return null;
  final absoluteFieldPos = tableOffset + rel;
  final fwdOffset = _readUint32(buf, absoluteFieldPos);
  return absoluteFieldPos + fwdOffset;
}

/// Read a string field from a table. Returns null if absent.
String? _tableString(ByteData buf, int tableOffset, int fieldIndex) {
  final absPos = _tableOffsetField(buf, tableOffset, fieldIndex);
  if (absPos == null) return null;
  return _readString(buf, absPos);
}

/// Read a uint16 vector field. Returns empty list if absent.
/// The vector stores count:uint32 followed by count × uint16 values.
List<int> _tableUint16Vector(ByteData buf, int tableOffset, int fieldIndex) {
  final vecPos = _tableOffsetField(buf, tableOffset, fieldIndex);
  if (vecPos == null) return const [];
  final count = _readUint32(buf, vecPos);
  final result = List<int>.filled(count, 0);
  for (int i = 0; i < count; i++) {
    result[i] = _readUint16(buf, vecPos + 4 + i * 2);
  }
  return result;
}

/// Read a vector of table offsets. Returns a list of absolute table positions.
List<int> _tableOffsetVector(ByteData buf, int tableOffset, int fieldIndex) {
  final vecPos = _tableOffsetField(buf, tableOffset, fieldIndex);
  if (vecPos == null) return const [];
  final count = _readUint32(buf, vecPos);
  final result = List<int>.filled(count, 0);
  for (int i = 0; i < count; i++) {
    final entryPos = vecPos + 4 + i * 4;
    final fwdOffset = _readUint32(buf, entryPos);
    result[i] = entryPos + fwdOffset;
  }
  return result;
}

// ---------------------------------------------------------------------------
// StarCatalogReader  (catalog_base.bin)
// ---------------------------------------------------------------------------

/// A single star entry read from catalog_base.bin.
class BinStar {
  final int hip;
  final double ra;
  final double dec;
  final double mag;
  final double colorIdx;

  const BinStar({
    required this.hip,
    required this.ra,
    required this.dec,
    required this.mag,
    required this.colorIdx,
  });
}

/// Reads the StarCatalog FlatBuffers table from a ByteData buffer.
class StarCatalogReader {
  final ByteData _buf;
  final List<int> _starOffsets;

  StarCatalogReader._(this._buf, this._starOffsets);

  factory StarCatalogReader(ByteData buf) {
    final rootOffset = _rootTableOffset(buf);
    final starOffsets = _tableOffsetVector(buf, rootOffset, 0);
    return StarCatalogReader._(buf, starOffsets);
  }

  int get starCount => _starOffsets.length;

  BinStar starAt(int index) {
    final tableOffset = _starOffsets[index];
    return BinStar(
      hip: _tableUint32(_buf, tableOffset, 0),
      ra: _tableFloat32(_buf, tableOffset, 1),
      dec: _tableFloat32(_buf, tableOffset, 2),
      mag: _tableFloat32(_buf, tableOffset, 3),
      colorIdx: _tableFloat32(_buf, tableOffset, 4),
    );
  }

  /// Returns all stars as a list.
  List<BinStar> readAll() {
    return List.generate(starCount, starAt);
  }
}

// ---------------------------------------------------------------------------
// WesternCultureReader  (culture_western.bin)
// ---------------------------------------------------------------------------

/// A single western constellation read from culture_western.bin.
class BinWesternConstellation {
  final String abbr;
  final String nameEn;
  final String nameZh;
  final int family;
  /// Interleaved [fromHip, toHip, fromHip, toHip, …] uint16 pairs.
  final List<int> edges;

  const BinWesternConstellation({
    required this.abbr,
    required this.nameEn,
    required this.nameZh,
    required this.family,
    required this.edges,
  });
}

/// Reads the WesternCulture FlatBuffers table from a ByteData buffer.
class WesternCultureReader {
  final ByteData _buf;
  final List<int> _constOffsets;

  WesternCultureReader._(this._buf, this._constOffsets);

  factory WesternCultureReader(ByteData buf) {
    final rootOffset = _rootTableOffset(buf);
    final offsets = _tableOffsetVector(buf, rootOffset, 0);
    return WesternCultureReader._(buf, offsets);
  }

  int get constellationCount => _constOffsets.length;

  BinWesternConstellation constellationAt(int index) {
    final tableOffset = _constOffsets[index];
    return BinWesternConstellation(
      abbr: _tableString(_buf, tableOffset, 0) ?? '',
      nameEn: _tableString(_buf, tableOffset, 1) ?? '',
      nameZh: _tableString(_buf, tableOffset, 2) ?? '',
      family: _tableUint8(_buf, tableOffset, 3),
      edges: _tableUint16Vector(_buf, tableOffset, 4),
    );
  }

  /// Returns all constellations as a list.
  List<BinWesternConstellation> readAll() {
    return List.generate(constellationCount, constellationAt);
  }
}

// ---------------------------------------------------------------------------
// ChineseCultureReader  (culture_chinese.bin)
// ---------------------------------------------------------------------------

/// A single Chinese asterism read from culture_chinese.bin.
class BinChineseAsterism {
  final String name;
  final String nameEn;
  final int quadrant;
  final int mansion;
  /// Interleaved [fromHip, toHip, fromHip, toHip, …] uint16 pairs.
  final List<int> edges;

  const BinChineseAsterism({
    required this.name,
    required this.nameEn,
    required this.quadrant,
    required this.mansion,
    required this.edges,
  });
}

/// Reads the ChineseCulture FlatBuffers table from a ByteData buffer.
class ChineseCultureReader {
  final ByteData _buf;
  final List<int> _asterismOffsets;

  ChineseCultureReader._(this._buf, this._asterismOffsets);

  factory ChineseCultureReader(ByteData buf) {
    final rootOffset = _rootTableOffset(buf);
    final offsets = _tableOffsetVector(buf, rootOffset, 0);
    return ChineseCultureReader._(buf, offsets);
  }

  int get asterismCount => _asterismOffsets.length;

  BinChineseAsterism asterismAt(int index) {
    final tableOffset = _asterismOffsets[index];
    return BinChineseAsterism(
      name: _tableString(_buf, tableOffset, 0) ?? '',
      nameEn: _tableString(_buf, tableOffset, 1) ?? '',
      quadrant: _tableUint8(_buf, tableOffset, 2),
      mansion: _tableUint8(_buf, tableOffset, 3),
      edges: _tableUint16Vector(_buf, tableOffset, 4),
    );
  }

  /// Returns all asterisms as a list.
  List<BinChineseAsterism> readAll() {
    return List.generate(asterismCount, asterismAt);
  }
}
