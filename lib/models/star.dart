class Star {
  final String id;
  final String name;
  final String? chineseName;
  final double rightAscension; // degrees
  final double declination;    // degrees
  final double magnitude;
  final String? spectralType;
  final String? description;
  final String? constellation;
  /// B−V colour index from the Hipparcos catalogue; null for JSON-loaded stars.
  final double? colorIdx;

  const Star({
    required this.id,
    required this.name,
    this.chineseName,
    required this.rightAscension,
    required this.declination,
    required this.magnitude,
    this.spectralType,
    this.description,
    this.constellation,
    this.colorIdx,
  });

  factory Star.fromJson(Map<String, dynamic> json) {
    return Star(
      id: json['id'] as String,
      name: json['name'] as String,
      chineseName: json['chineseName'] as String?,
      rightAscension: (json['rightAscension'] as num).toDouble(),
      declination: (json['declination'] as num).toDouble(),
      magnitude: (json['magnitude'] as num).toDouble(),
      spectralType: json['spectralType'] as String?,
      description: json['description'] as String?,
      constellation: json['constellation'] as String?,
      colorIdx: (json['colorIdx'] as num?)?.toDouble(),
    );
  }

  factory Star.fromBin({
    required int hip,
    required double ra,
    required double dec,
    required double mag,
    required double colorIdx,
    String? nameEn,
    String? nameZh,
  }) {
    return Star(
      id: 'hip_$hip',
      name: nameEn ?? 'HIP $hip',
      chineseName: nameZh,
      rightAscension: ra,
      declination: dec,
      magnitude: mag,
      colorIdx: colorIdx,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'chineseName': chineseName,
        'rightAscension': rightAscension,
        'declination': declination,
        'magnitude': magnitude,
        'spectralType': spectralType,
        'description': description,
        'constellation': constellation,
        'colorIdx': colorIdx,
      };
}
