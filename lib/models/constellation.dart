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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'chineseName': chineseName,
        'starIds': starIds,
        'lines': lines.map((l) => l.toJson()).toList(),
        'description': description,
      };
}
