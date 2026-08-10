import 'dart:async';
import '../../../../core/l10n/tr.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/news_datasource.dart';
import '../../data/models/news_item_model.dart';
import 'news_story_tile.dart';

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

  Widget _chip(BuildContext context, int index, IconData icon, String label) {
    final selected = _tabController.index == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _tabController.animateTo(index)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : context.cBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color: selected ? Colors.white : context.cTextSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? Colors.white : context.cTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                // Flexible, not bare: a Row with a Spacer gives an unbounded
                // Text all the width it asks for and then overflows. The label
                // is longer in Tamil ("செய்திகள் · News") than in English, so
                // this only broke for the members who read it in Tamil — on
                // narrow phones, which is most of them.
                Flexible(
                  child: Text(
                    trId('news_2'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.cText,
                    ),
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
                  tooltip: trId('refresh_news'),
                ),
              ],
            ),
          ),
          // Pills, not an underlined tab bar.
          //
          // An underline marks the selected tab and leaves the rest as plain
          // text, so on a dark card the five sections read as a sentence and
          // the one you are on is a thin line most people miss. A filled pill
          // says which is selected from across the room, which is how far away
          // a phone is when somebody is deciding whether to keep scrolling.
          SizedBox(
            height: 40,
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // These two were hardcoded Tamil — the same bug as a
                  // hardcoded English label, just pointed the other way.
                  _chip(context, 0, Icons.place_rounded, trId('kanyakumari_news')),
                  _chip(context, 1, Icons.language_rounded, trId('tamil_news')),
                  _chip(context, 2, Icons.public_rounded, trId('india_news')),
                  _chip(context, 3, Icons.work_outline_rounded, trId('tn_jobs')),
                  _chip(context, 4, Icons.account_balance_rounded, trId('central_news')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Fixed height so the page does not jump while loading. Raised from
          // 380 when the lead story gained a picture: at the old height the
          // hero left room for exactly one headline beneath it, which is a
          // magazine cover rather than a news feed.
          SizedBox(
            height: 640,
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
          // The first story gets the weight.
          //
          // Eight identical grey rows is a search results page: nothing tells
          // a member which of these matters, so every one costs the same
          // glance and none of them is read. Giving the lead story a larger
          // headline is the oldest thing a front page does, and it is the
          // difference between a list and an edition.
          itemBuilder: (_, i) => _NewsRow(
            item: items[i],
            jobMode: widget.jobMode,
            isLead: i == 0 && !widget.jobMode,
          ),
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
          Text(trId('couldn_t_load_news'),
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.cText,
                  fontSize: 13)),
          const SizedBox(height: 4),
          Text(trId('check_connection_and_try_again'),
              style: TextStyle(fontSize: 11, color: context.cTextSecondary)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, size: 16, color: AppColors.background),
            label: Text(trId('retry_6'), style: TextStyle(color: AppColors.background)),
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
          Text(trId('no_news_available'),
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.cText,
                  fontSize: 13)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, size: 16, color: AppColors.background),
            label: Text(trId('retry_6'), style: TextStyle(color: AppColors.background)),
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

  /// The top story, set larger. Job listings have no lead — they are a list on
  /// purpose, and one of them is not more important than the others.
  final bool isLead;

  const _NewsRow({required this.item, this.jobMode = false, this.isLead = false});

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _open() {
    if (item.link.isNotEmpty) {
      launchUrl(Uri.parse(item.link), mode: LaunchMode.externalApplication);
    }
  }

  /// The top story, given the room a top story earns.
  ///
  /// A list where every headline is the same size says every headline matters
  /// equally, which is never true and makes a member read all of them to find
  /// the one that does. The lead gets the picture, the space and the label; the
  /// rest get a thumbnail and one line of context.
  Widget _hero(BuildContext context) {
    final time = newsAgo(item.publishedAt);
    return InkWell(
      onTap: _open,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            // A shade off the card rather than the page's own black — inside a
            // surface, true background reads as a hole punched through it.
            color: context.isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            border: Border.all(color: context.cBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  NewsThumb(
                      item: item,
                      size: const Size(double.infinity, 168),
                      radius: 0),
                  // A scrim, so a white sky behind white type does not eat the
                  // label. Cheap, and it makes the badge legible on any photo.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.55],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        jobMode ? trId('jobs_3') : trId('top_story'),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (time.isNotEmpty)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(time,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white)),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        height: 1.32,
                        color: context.cText,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.source,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.north_east,
                            size: 14, color: context.cTextSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLead) return _hero(context);
    return InkWell(
      onTap: _open,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The picture earns its place by making a list scannable: a member
            // recognises a story by its photograph before they have read a word
            // of the headline.
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: NewsThumb(item: item, size: const Size(64, 64)),
            ),
            if (jobMode)
              Container(
                margin: const EdgeInsets.only(right: 10, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  trId('jobs_3'),
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
                      fontSize: isLead ? 17 : 13.5,
                      fontWeight: isLead ? FontWeight.w800 : FontWeight.w600,
                      height: 1.3,
                      color: context.cText,
                    ),
                    maxLines: isLead ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.source,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // No time rather than a wrong one. Stories that arrive
                      // without a publication date used to be stamped with the
                      // moment of the fetch, so every item read "3m".
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
            const ShimmerBox(height: 10, width: 100),
            const SizedBox(height: 12),
            if (i < 4)
              Divider(height: 1, color: context.cBorder),
          ],
        ],
      ),
    );
  }
}
