/// One answer to a query.
///
/// Two things here were previously the app's problem and are now the server's,
/// because the server is the only side that knows what it found:
///
/// * **[route]** — where tapping goes. The screen used to keep its own
///   type→route map that sent every result to a section index, so finding one
///   specific member and tapping them landed you on the full roster.
/// * **[score]** — relevance, already applied. Results arrive in order, so the
///   screen renders a list instead of inventing a ranking out of per-type
///   buckets it received in arbitrary order.
///
/// [type] is still carried, but only to choose an icon and a section heading —
/// never to decide where the result leads.
class SearchHit {
  final String id;
  final String type;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String route;
  final int score;

  const SearchHit({
    required this.id,
    required this.type,
    required this.title,
    required this.route,
    this.subtitle,
    this.imageUrl,
    this.score = 0,
  });

  /// A place in the app rather than a thing in it — the events page, the blood
  /// hub, the complaint box. Shown first and labelled differently, because
  /// "go here" is a different kind of answer from "here is a match".
  bool get isDestination => type == 'DESTINATION';

  factory SearchHit.fromJson(Map<String, dynamic> json) => SearchHit(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'UNKNOWN',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString(),
        imageUrl: json['image_url']?.toString(),
        route: json['route']?.toString() ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
      );
}
