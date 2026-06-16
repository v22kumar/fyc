/// A single Tamil news headline sourced from Google News RSS.
class NewsItemModel {
  final String title;
  final String source;
  final String link;
  final DateTime? publishedAt;

  const NewsItemModel({
    required this.title,
    required this.source,
    required this.link,
    this.publishedAt,
  });

  factory NewsItemModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['published_at'] as String?;
    return NewsItemModel(
      title: (json['title'] as String?) ?? '',
      source: (json['source'] as String?) ?? '',
      link: (json['link'] as String?) ?? '',
      publishedAt: rawDate != null ? DateTime.tryParse(rawDate) : null,
    );
  }
}
