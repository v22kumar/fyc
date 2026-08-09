import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/photo_entity.dart';
import '../bloc/gallery_bloc.dart';
import '../bloc/gallery_event.dart';
import '../bloc/gallery_state.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String get _lang => trLang();

  @override
  void initState() {
    super.initState();
    context.read<GalleryBloc>().add(const GalleryFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(trId('gallery')),
      ),
      body: BlocBuilder<GalleryBloc, GalleryState>(
        builder: (context, state) {
          if (state is GalleryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is GalleryLoaded) {
            if (state.photos.isEmpty) {
              return _EmptyGallery(lang: _lang);
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<GalleryBloc>().add(const GalleryFetchRequested());
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 600 ? 3 : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: state.photos.length,
                    itemBuilder: (context, index) {
                      final photo = state.photos[index];
                      return _PhotoThumbnail(
                        photo: photo,
                        onTap: () => context.go('/gallery/photo', extra: photo),
                      );
                    },
                  );
                },
              ),
            );
          }
          if (state is GalleryFailure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<GalleryBloc>()
                        .add(const GalleryFetchRequested()),
                    child: Text(
                        trId('retry')),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final PhotoEntity photo;
  final VoidCallback onTap;

  const _PhotoThumbnail({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
        child: Image.network(
          photo.absoluteUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: AppColors.border,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stack) => Container(
            color: AppColors.border,
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.textSecondary,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyGallery extends StatelessWidget {
  final String lang;
  const _EmptyGallery({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📷', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            trId('no_photos_yet'),
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
