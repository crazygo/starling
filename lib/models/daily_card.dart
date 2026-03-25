class DailyCard {
  final String id;
  final String date;         // ISO 8601 date string, e.g. "2024-01-15"
  final String title;
  final String? chineseTitle;
  final String body;
  final String imageUrl;
  final String? wikipediaUrl;
  final String? relatedStarId;

  const DailyCard({
    required this.id,
    required this.date,
    required this.title,
    this.chineseTitle,
    required this.body,
    required this.imageUrl,
    this.wikipediaUrl,
    this.relatedStarId,
  });

  factory DailyCard.fromJson(Map<String, dynamic> json) {
    return DailyCard(
      id: json['id'] as String,
      date: json['date'] as String,
      title: json['title'] as String,
      chineseTitle: json['chineseTitle'] as String?,
      body: json['body'] as String,
      imageUrl: json['imageUrl'] as String,
      wikipediaUrl: json['wikipediaUrl'] as String?,
      relatedStarId: json['relatedStarId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'chineseTitle': chineseTitle,
        'body': body,
        'imageUrl': imageUrl,
        'wikipediaUrl': wikipediaUrl,
        'relatedStarId': relatedStarId,
      };
}
