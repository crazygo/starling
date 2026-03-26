class ConstellationLine {
  final String starId1;
  final String starId2;

  const ConstellationLine({
    required this.starId1,
    required this.starId2,
  });

  factory ConstellationLine.fromJson(Map<String, dynamic> json) {
    return ConstellationLine(
      starId1: json['starId1'] as String,
      starId2: json['starId2'] as String,
    );
  }

  /// Creates a [ConstellationLine] from two Hipparcos catalogue IDs.
  factory ConstellationLine.fromHip(int fromHip, int toHip) {
    return ConstellationLine(
      starId1: 'hip_$fromHip',
      starId2: 'hip_$toHip',
    );
  }

  Map<String, dynamic> toJson() => {
        'starId1': starId1,
        'starId2': starId2,
      };
}

class Constellation {
  final String id;
  final String name;
  final String? chineseName;
  final List<String> starIds;
  final List<ConstellationLine> lines;
  final String? description;

  const Constellation({
    required this.id,
    required this.name,
    this.chineseName,
    required this.starIds,
    required this.lines,
    this.description,
  });

  factory Constellation.fromJson(Map<String, dynamic> json) {
    return Constellation(
      id: json['id'] as String,
      name: json['name'] as String,
      chineseName: json['chineseName'] as String?,
      starIds: List<String>.from(json['starIds'] as List),
      lines: (json['lines'] as List)
          .map((l) => ConstellationLine.fromJson(l as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String?,
    );
  }

  /// Creates a [Constellation] from a western IAU binary record.
  ///
  /// [edgePairs] is an interleaved list of [fromHip, toHip, …] uint16 values.
  factory Constellation.fromWesternBin({
    required String abbr,
    required String nameEn,
    required String nameZh,
    required List<int> edgePairs,
  }) {
    final lines = <ConstellationLine>[];
    final hipSet = <int>{};
    for (int i = 0; i + 1 < edgePairs.length; i += 2) {
      final from = edgePairs[i];
      final to = edgePairs[i + 1];
      lines.add(ConstellationLine.fromHip(from, to));
      hipSet.add(from);
      hipSet.add(to);
    }
    final starIds = hipSet.map((h) => 'hip_$h').toList();
    return Constellation(
      id: abbr.toLowerCase(),
      name: nameEn,
      chineseName: nameZh.isEmpty ? null : nameZh,
      starIds: starIds,
      lines: lines,
    );
  }

  /// Creates a [Constellation] from a Chinese asterism binary record.
  ///
  /// [edgePairs] is an interleaved list of [fromHip, toHip, …] uint16 values.
  factory Constellation.fromChineseBin({
    required String name,
    String? nameEn,
    required List<int> edgePairs,
  }) {
    final lines = <ConstellationLine>[];
    final hipSet = <int>{};
    for (int i = 0; i + 1 < edgePairs.length; i += 2) {
      final from = edgePairs[i];
      final to = edgePairs[i + 1];
      lines.add(ConstellationLine.fromHip(from, to));
      hipSet.add(from);
      hipSet.add(to);
    }
    final starIds = hipSet.map((h) => 'hip_$h').toList();
    return Constellation(
      id: name,
      name: nameEn ?? name,
      chineseName: name,
      starIds: starIds,
      lines: lines,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'chineseName': chineseName,
        'starIds': starIds,
        'lines': lines.map((l) => l.toJson()).toList(),
        'description': description,
      };
}
