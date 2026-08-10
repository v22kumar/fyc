import 'package:flutter/material.dart';

import '../../data/models/news_item_model.dart';

/// The picture beside a headline — or, when there is no picture, something
/// that still looks deliberate.
///
/// Most headlines will have one: the backend resolves each publisher's
/// og:image. Some will not, because the publisher blocked us, was slow, or
/// simply has no image, and that is a normal outcome rather than a failure.
///
/// The fallback is not a grey box. A grey box in a list of photographs reads as
/// broken, and a member scrolling past three of them concludes the app is
/// broken. Instead the story's own headline seeds a colour, so the same article
/// always gets the same tile, the list stays visually varied, and nothing looks
/// like a hole where a picture failed to load.
class NewsThumb extends StatelessWidget {
  const NewsThumb({
    super.key,
    required this.item,
    required this.size,
    this.radius = 14,
  });

  final NewsItemModel item;
  final Size size;
  final double radius;

  /// Deterministic from the headline, so a story keeps its colour between
  /// refreshes instead of flickering to a new one every thirty minutes.
  static const _palette = <List<Color>>[
    [Color(0xFF7C3AED), Color(0xFF4C1D95)],
    [Color(0xFF0891B2), Color(0xFF164E63)],
    [Color(0xFFB45309), Color(0xFF78350F)],
    [Color(0xFF15803D), Color(0xFF14532D)],
    [Color(0xFFBE185D), Color(0xFF831843)],
    [Color(0xFF4338CA), Color(0xFF1E1B4B)],
  ];

  List<Color> get _colours {
    var hash = 0;
    for (final unit in item.title.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final colours = _colours;
    final placeholder = Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colours,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.article_rounded,
          size: size.width * 0.30, color: Colors.white.withValues(alpha: 0.55)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: item.imageUrl == null
          ? placeholder
          : Image.network(
              item.imageUrl!,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
              // A picture that is still arriving must not collapse the row and
              // then push it back open — the list would jump under the thumb
              // the member is reaching for.
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
              errorBuilder: (_, __, ___) => placeholder,
            ),
    );
  }
}

/// How long ago, in the shape a person says it.
String newsAgo(DateTime? at) {
  if (at == null) return '';
  final gap = DateTime.now().difference(at);
  if (gap.inMinutes < 1) return 'now';
  if (gap.inMinutes < 60) return '${gap.inMinutes}m ago';
  if (gap.inHours < 24) return '${gap.inHours}h ago';
  return '${gap.inDays}d ago';
}
