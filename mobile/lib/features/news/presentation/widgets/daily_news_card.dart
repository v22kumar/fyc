import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/news_datasource.dart';
import '../../data/models/news_item_model.dart';

/// News card with five tabs: Kanyakumari local, Tamil, India, TN Jobs, Central Jobs.
/// Sourced from Google News RSS via the backend proxy.
class DailyNewsCard extends StatefulWidget {
  const DailyNewsCard({super.key});

  @override
  State<DailyNewsCard> createState() => _DailyNewsCardState();
}

class _DailyNewsCardState extends State<DailyNewsCard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late Future<List<NewsItemModel>> _kanyakumariFuture;
  late Future<List<NewsItemModel>> _tamilFuture;
  late Future<List<NewsItemModel>> _indiaFuture;
  late Future<List<NewsItemModel>> _tnJobsFuture;
  late Future<List<NewsItemModel>> _centralJobsFuture;

  // Version counter: incrementing this tells _NewsFeed a fresh future arrived.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initFutures();
  }

  void _initFutures() {
    final ds = sl<NewsDataSource>();
    // No dart .timeout() here — _NewsFeed owns the UI-level failsafe timer.
    _kanyakumariFuture = ds.fetchKanyakumari(limit: 8);
    _tamilFuture       = ds.fetchTop(limit: 10);
    _indiaFuture       = ds.fetchIndia(limit: 5);
    _tnJobsFuture      = ds.fetchTnJobs(limit: 8);
    _centralJobsFuture = ds.fetchCentralJobs(limit: 8);
    _version++;
  }

  void _retry() => setState(_initFutures);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: context.cBorder),
        boxShadow: context.isDark ? null : AppTheme.cardShadow,
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
                Text(
                  'செய்திகள் · News',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.cText,
                  ),
                ),
                const Spacer(),
                // Manual refresh icon
                IconButton(
                  onPressed: _retry,
                  icon: Icon(Icons.refresh_rounded,
                      size: 18, color: context.cTextSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Refresh news',
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: context.cTextSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            tabs: const [
              Tab(text: 'கன்னியாகுமரி'),
              Tab(text: 'தமிழ்'),
              Tab(text: 'India'),
              Tab(text: 'TN Jobs'),
              Tab(text: 'Central'),
            ],
          ),
          // Content — fixed height so page doesn't jump when loading
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [
                _NewsFeed(key: ValueKey('kk-$_version'), future: _kanyakumariFuture, onRetry: _retry),
                _NewsFeed(key: ValueKey('ta-$_version'), future: _tamilFuture, onRetry: _retry),
                _NewsFeed(key: ValueKey('in-$_version'), future: _indiaFuture, onRetry: _retry),
                _NewsFeed(key: ValueKey('tnj-$_version'), future: _tnJobsFuture, jobMode: true, onRetry: _retry),
                _NewsFeed(key: ValueKey('cj-$_version'), future: _centralJobsFuture, jobMode: true, onRetry: _retry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _NewsFeed ────────────────────────────────────────────────────────────────

class _NewsFeed extends StatefulWidget {
  final Future<List<NewsItemModel>> future;
  final bool jobMode;
  final VoidCallback onRetry;
  const _NewsFeed({
    super.key,
    required this.future,
    this.jobMode = false,
    required this.onRetry,
  });

  @override
  State<_NewsFeed> createState() => _NewsFeedState();
}

class _NewsFeedState extends State<_NewsFeed> {
  // Hard UI-level failsafe: if the future hasn't resolved after 10 s, show
  // the error/retry state so the user is never stuck in grey indefinitely.
  static const _kUiTimeout = Duration(seconds: 10);

  Timer? _timer;
  bool _uiTimedOut = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _uiTimedOut = false;
    _timer?.cancel();
    _timer = Timer(_kUiTimeout, () {
      if (mounted) setState(() => _uiTimedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NewsItemModel>>(
      future: widget.future,
      builder: (context, snapshot) {
        // Still waiting — cancel timer once done
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_uiTimedOut) {
            return _ErrorState(onRetry: widget.onRetry);
          }
          return const _NewsSkeleton();
        }

        // Future resolved — cancel the failsafe timer
        _timer?.cancel();

        if (snapshot.hasError) {
          return _ErrorState(onRetry: widget.onRetry);
        }

        final items = snapshot.data;
        if (items == null || items.isEmpty) {
          return _EmptyState(onRetry: widget.onRetry);
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: context.cBorder),
          ),
          itemBuilder: (_, i) => _NewsRow(item: items[i], jobMode: widget.jobMode),
        );
      },
    );
  }
}

// ─── Error / Empty states ────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: context.cTextSecondary),
          const SizedBox(height: 10),
          Text('Couldn\'t load news',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.cText,
                  fontSize: 13)),
          const SizedBox(height: 4),
          Text('Check connection and try again',
              style: TextStyle(fontSize: 11, color: context.cTextSecondary)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.newspaper_rounded, size: 36, color: context.cTextSecondary),
          const SizedBox(height: 8),
          Text('No news available',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.cText,
                  fontSize: 13)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── News row ─────────────────────────────────────────────────────────────────

class _NewsRow extends StatelessWidget {
  final NewsItemModel item;
  final bool jobMode;
  const _NewsRow({required this.item, this.jobMode = false});

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
            if (jobMode)
              Container(
                margin: const EdgeInsets.only(right: 10, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'JOBS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: context.cText,
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
                        Text(' • ',
                            style: TextStyle(
                                fontSize: 11, color: context.cTextSecondary)),
                        Text(
                          _relativeTime(item.publishedAt),
                          style: TextStyle(
                              fontSize: 11, color: context.cTextSecondary),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.north_east, size: 14, color: context.cTextSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _NewsSkeleton extends StatelessWidget {
  const _NewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < 5; i++) ...[
            const SizedBox(height: 12),
            ShimmerBox(height: 14, width: i.isEven ? double.infinity : 280),
            const SizedBox(height: 6),
            ShimmerBox(height: 12, width: i.isOdd ? 240 : 200),
            const SizedBox(height: 6),
            ShimmerBox(height: 10, width: 100),
            const SizedBox(height: 12),
            if (i < 4)
              Divider(height: 1, color: context.cBorder),
          ],
        ],
      ),
    );
  }
}
