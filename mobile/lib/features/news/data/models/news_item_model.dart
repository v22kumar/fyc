/// A single Tamil news headline sourced from Google News RSS.
class NewsItemModel {
  final String title;
  final String source;
  final String link;
  final DateTime? publishedAt;

  /// The publisher's own picture for this article, when the backend found one.
  ///
  /// Nullable and expected to be: Google News RSS carries no images, so the
  /// server resolves them from each publisher's og:image within a time budget.
  /// A headline that arrives without one is still news — the card draws a
  /// generated tile in the story's own colour rather than a grey hole.
  final String? imageUrl;

  const NewsItemModel({
    required this.title,
    required this.source,
    required this.link,
    this.publishedAt,
    this.imageUrl,
  });

  factory NewsItemModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['published_at'] as String?;
    return NewsItemModel(
      title: (json['title'] as String?) ?? '',
      source: (json['source'] as String?) ?? '',
      link: (json['link'] as String?) ?? '',
      publishedAt: rawDate != null ? DateTime.tryParse(rawDate) : null,
      imageUrl: (json['image_url'] as String?)?.trim().isNotEmpty == true
          ? (json['image_url'] as String)
          : null,
    );
  }
}
