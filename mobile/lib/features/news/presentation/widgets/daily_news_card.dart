import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/news_datasource.dart';
import '../../data/models/news_item_model.dart';

/// News card with three tabs: Tamil (10), India (5), Jobs (4).
/// Sourced from Google News RSS via the backend proxy.
/// Fails silently if offline — never disrupts the home screen.
class DailyNewsCard extends StatefulWidget {
  const DailyNewsCard({super.key});

  @override
  State<DailyNewsCard> createState() => _DailyNewsCardState();
}

class _DailyNewsCardState extends State<DailyNewsCard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late Future<List<NewsItemModel>> _tamilFuture;
  late Future<List<NewsItemModel>> _indiaFuture;
  late Future<List<NewsItemModel>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final ds = sl<NewsDataSource>();
    _tamilFuture = ds.fetchTop(limit: 10);
    _indiaFuture = ds.fetchIndia(limit: 5);
    _jobsFuture = ds.fetchJobs(limit: 4);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                const Text(
                  'செய்திகள் · News',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            tabs: const [
              Tab(text: 'தமிழ்'),
              Tab(text: 'India'),
              Tab(text: 'Jobs'),
            ],
          ),
          // Content
          SizedBox(
            height: 340,
            child: TabBarView(
              controller: _tabController,
              children: [
                _NewsFeed(future: _tamilFuture),
                _NewsFeed(future: _indiaFuture),
                _NewsFeed(future: _jobsFuture),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsFeed extends StatelessWidget {
  final Future<List<NewsItemModel>> future;
  const _NewsFeed({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NewsItemModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _NewsSkeleton();
        }
        final items = snapshot.data;
        if (items == null || items.isEmpty) {
          return const Center(
            child: Text(
              'No news available',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: AppColors.border),
          ),
          itemBuilder: (_, i) => _NewsRow(item: items[i]),
        );
      },
    );
  }
}

class _NewsRow extends StatelessWidget {
  final NewsItemModel item;
  const _NewsRow({required this.item});

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
                      Flexible(
                        child: Text(
                          item.source,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_relativeTime(item.publishedAt).isNotEmpty) ...[
                        const Text(' • ',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                        Text(
                          _relativeTime(item.publishedAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < 3; i++) ...[
            ShimmerBox(height: 13, width: i.isEven ? 240 : 180),
            const SizedBox(height: 8),
            const ShimmerBox(height: 10, width: 100),
            if (i != 2) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
