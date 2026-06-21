import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'shimmer_box.dart';

/// Drop-in replacement for Image.network with caching + shimmer placeholder.
class CachedImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;

  const CachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _fallback();

    Widget image = CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => ShimmerSkeleton(
        width: width ?? double.infinity,
        height: height ?? 120,
        borderRadius: borderRadius?.topLeft.y ?? 8,
      ),
      errorWidget: (_, __, ___) => errorWidget ?? _fallback(),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _fallback() => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: borderRadius,
        ),
        child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFFCBD5E1), size: 32),
      );
}
