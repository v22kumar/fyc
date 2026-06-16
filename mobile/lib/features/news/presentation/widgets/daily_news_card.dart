import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/news_datasource.dart';
import '../../data/models/news_item_model.dart';

/// Minimal "Top 10 Tamil headlines" card for the home screen, sourced from
/// Google News RSS. Each row opens the original article externally.
///
/// Non-critical: if the fetch fails (e.g. offline) the card renders nothing
/// rather than showing an error, so it never disrupts the home screen.
class DailyNewsCard extends StatefulWidget {
  const DailyNewsCard({super.key});

  @override
  State<DailyNewsCard> createState() => _DailyNewsCardState();
}

class _DailyNewsCardState extends State<DailyNewsCard> {
  late Future<List<NewsItemModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<NewsDataSource>().fetchTop(limit: 10);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NewsItemModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _NewsSkeleton();
        }
        final items = snapshot.data;
        if (items == null || items.isEmpty) {
          return const SizedBox.shrink(); // fail silently
        }
        return _NewsContent(items: items);
      },
    );
  }
}

class _NewsContent extends StatelessWidget {
  final List<NewsItemModel> items;
  const _NewsContent({required this.items});

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('📰', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'இன்றைய செய்திகள்',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Text(
                  'Top 10',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < items.length; i++) ...[
            _NewsRow(item: items[i], relativeTime: _relativeTime(items[i].publishedAt)),
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1, color: AppColors.border),
              ),
          ],
        ],
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  final NewsItemModel item;
  final String relativeTime;
  const _NewsRow({required this.item, required this.relativeTime});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (item.link.isNotEmpty) {
          launchUrl(Uri.parse(item.link), mode: LaunchMode.externalApplication);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.source,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (relativeTime.isNotEmpty) ...[
                        const Text(' • ',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text(
                          relativeTime,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.north_east, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _NewsSkeleton extends StatelessWidget {
  const _NewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
        ),
      ),
    );
  }
}
