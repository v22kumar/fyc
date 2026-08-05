import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../patterns/kolam_background.dart';
import '../tokens.dart';

/// The one header every screen wears.
///
/// Before this, each section drew its own: a photographic banner on Home, a
/// dark block with a tagline on Feed, a flat bar on Events, a bare title on Me,
/// and on Chess no bar at all — just a back arrow floating over the content.
/// Five treatments and four different greens, which is what happens when
/// screens are built one at a time and never seen side by side.
///
/// This is deliberately richer than the flat bars it replaces, not plainer.
/// Consistency was not worth buying with a downgrade: every variant carries the
/// club's kolam texture and a vertical tone shift, so a header reads as a
/// crafted surface rather than a block of colour.
class DSScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const DSScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.image,
    this.bottom,
    this.variant = DSHeaderVariant.standard,
  });

  /// A screen title. Short, in the member's language.
  final String title;

  /// One line of orientation. Omit rather than pad it with a slogan.
  final String? subtitle;

  /// Icon actions, right-aligned. Keep to two — a header is not a toolbar.
  final List<Widget> actions;

  /// Back affordance. Null hides it (top-level tabs have nowhere to go back to).
  final VoidCallback? onBack;

  /// Optional photograph behind the header. Always scrimmed so the title holds
  /// contrast no matter what the image is — the alternative is white-on-sky.
  final ImageProvider? image;

  /// Tabs or filters that belong to the header rather than the body, so they
  /// sit on the brand surface and scroll with it.
  final PreferredSizeWidget? bottom;

  final DSHeaderVariant variant;

  @override
  Size get preferredSize {
    final base = switch (variant) {
      DSHeaderVariant.compact => 56.0,
      DSHeaderVariant.standard => subtitle == null ? 72.0 : 92.0,
      DSHeaderVariant.hero => 168.0,
    };
    return Size.fromHeight(base + (bottom?.preferredSize.height ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    const onBrand = Colors.white;
    final primary = AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        // A single vertical step rather than a flat fill: enough to give the
        // surface depth, not so much that it reads as a gradient.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(primary, Colors.black, 0.18)!,
            primary,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (image != null)
            Positioned.fill(
              child: Image(image: image!, fit: BoxFit.cover),
            ),
          if (image != null)
            // The scrim is what makes an arbitrary photograph safe to put text
            // on. Darkest at the bottom, where the title sits.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primary.withOpacity(0.55),
                      Color.lerp(primary, Colors.black, 0.35)!.withOpacity(0.92),
                    ],
                  ),
                ),
              ),
            ),
          if (image == null)
            Positioned.fill(
              child: KolamBackground(
                color: onBrand,
                opacity: 0.10,
                child: const SizedBox.expand(),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    onBack != null ? DSSpacing.xs : DSSpacing.md,
                    DSSpacing.sm,
                    DSSpacing.sm,
                    variant == DSHeaderVariant.hero ? DSSpacing.md : DSSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (onBack != null)
                        // A real 48dp target in the bar, rather than a floating
                        // square that lands on whatever is behind it.
                        IconButton(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back),
                          color: onBrand,
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: (variant == DSHeaderVariant.hero
                                      ? Theme.of(context).textTheme.headlineLarge
                                      : Theme.of(context).textTheme.headlineMedium)
                                  ?.copyWith(color: onBrand),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: onBrand.withOpacity(0.82)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ...actions.map((a) => IconTheme.merge(
                            data: IconThemeData(color: onBrand),
                            child: a,
                          )),
                    ],
                  ),
                ),
                if (bottom != null) bottom!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum DSHeaderVariant {
  /// Detail pages reached from somewhere else.
  compact,

  /// The default: a screen title, optionally a line of orientation.
  standard,

  /// Section landings that deserve a photograph.
  hero,
}
