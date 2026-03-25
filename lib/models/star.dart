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
      };
}
