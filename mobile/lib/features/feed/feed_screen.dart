import 'package:flutter/material.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../service_locator.dart';
import 'feed_api.dart';
import 'feed_models.dart';
import '../../core/services/sync_service.dart';

String _fullUrl(String url) =>
    url.startsWith('http') ? url : '${ApiConstants.baseUrl}$url';

String _ago(DateTime d, bool ta) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) {
    return tr(en: 'just now', ta: 'இப்போது', hi: 'अभी', ml: 'ഇപ്പോൾ');
  }
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

// Category tabs → backend category filter.
const _tabs = <(String, IconData, String?)>[
  ('All Posts', Icons.dynamic_feed, null),
  ('Club Updates', Icons.campaign_outlined, 'Announcement'),
  ('Events', Icons.event_outlined, 'Events'),
  ('Achievements', Icons.emoji_events_outlined, 'Achievements'),
];

// Filter chips → backend feed sort.
const _filters = <(String, IconData, String)>[
  ('All', Icons.grid_view_rounded, 'recent'),
  ('Popular', Icons.local_fire_department_outlined, 'popular'),
  ('Recent', Icons.schedule, 'recent'),
  ('Following', Icons.person_outline, 'following'),
];

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool get _ta => sl<LocalStorage>().getLang() == 'ta';

  int _tab = 0;
  int _filter = 0;

  List<Post>? _posts;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final posts = await FeedApi.list(
        feed: _filters[_filter].$3,
        category: _tabs[_tab].$3,
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCreate() async {
    final created = await context.push<bool>('/feed/create');
    if (created == true) _load();
  }

  void _selectTab(int i) {
    if (_tab == i) return;
    setState(() => _tab = i);
    _load();
  }

  void _selectFilter(int i) {
    if (_filter == i) return;
    setState(() => _filter = i);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(onCreate: _openCreate)),
            SliverToBoxAdapter(
              child: _TabsBar(active: _tab, onSelect: _selectTab),
            ),
            SliverToBoxAdapter(
              child: _FilterChips(active: _filter, onSelect: _selectFilter),
            ),
            _buildBody(),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _posts == null) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error && _posts == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.wifi_off_rounded, size: 40, color: context.cTextSecondary),
                const SizedBox(height: 12),
                Text(tr(en: "Couldn't load the feed", ta: 'சுவரை ஏற்ற முடியவில்லை',
                    hi: 'फ़ीड लोड नहीं हुआ', ml: 'ഫീഡ് ലോഡ് ചെയ്യാനായില്ല')),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _load,
                    child: Text(tr(en: 'Retry', ta: 'மீண்டும்', hi: 'पुनः', ml: 'വീണ്ടും'))),
              ],
            ),
          ),
        ),
      );
    }
    final posts = _posts ?? const [];
    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 70),
          child: Center(
            child: Column(
              children: [
                const Text('🗞️', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                Text(tr(en: 'No posts yet', ta: 'இன்னும் இடுகைகள் இல்லை',
                    hi: 'अभी कोई पोस्ट नहीं', ml: 'ഇതുവരെ പോസ്റ്റുകളില്ല'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.cText)),
                const SizedBox(height: 4),
                Text(tr(en: 'Be the first to share something!',
                    ta: 'முதலில் பகிருங்கள்!', hi: 'सबसे पहले साझा करें!',
                    ml: 'ആദ്യം പങ്കിടൂ!'),
                    style: TextStyle(fontSize: 12.5, color: context.cTextSecondary)),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _PostCard(post: posts[i], ta: _ta),
          childCount: posts.length,
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onCreate;
  const _Header({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16, right: 16, bottom: 44),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A3D2A), Color(0xFF0F5132)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/fyc_logo.png',
                    width: 40, height: 40,
                    errorBuilder: (_, __, ___) => const Icon(Icons.shield,
                        color: Colors.white, size: 36)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(en: 'Community Feed', ta: 'சமூக சுவர்',
                          hi: 'समुदाय फ़ीड', ml: 'കമ്മ്യൂണിറ്റി ഫീഡ്'),
                      style: const TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                    Text(
                      tr(en: 'Stay connected. Share. Inspire.',
                          ta: 'இணைந்திருங்கள். பகிருங்கள்.',
                          hi: 'जुड़े रहें। साझा करें।',
                          ml: 'ബന്ധപ്പെട്ടിരിക്കൂ. പങ്കിടൂ.'),
                      style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
        ),
        // Composer bar overlapping the header bottom.
        Positioned(
          left: 16, right: 16, bottom: -28,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(16),
            color: context.cSurface,
            child: InkWell(
              onTap: onCreate,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withOpacity(0.15),
                      child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(en: "What's happening in your community?",
                            ta: 'உங்கள் சமூகத்தில் என்ன நடக்கிறது?',
                            hi: 'आपके समुदाय में क्या हो रहा है?',
                            ml: 'നിങ്ങളുടെ സമൂഹത്തിൽ എന്താണ്?'),
                        style: TextStyle(color: context.cTextSecondary, fontSize: 13),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit, color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(tr(en: 'Post', ta: 'இடு', hi: 'पोस्ट', ml: 'പോസ്റ്റ്'),
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Category tabs ────────────────────────────────────────────────────

class _TabsBar extends StatelessWidget {
  final int active;
  final void Function(int) onSelect;
  const _TabsBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    String label(String en) => switch (en) {
          'All Posts' => tr(en: 'All Posts', ta: 'எல்லாம்', hi: 'सभी', ml: 'എല്ലാം'),
          'Club Updates' => tr(en: 'Club Updates', ta: 'கிளப்', hi: 'क्लब', ml: 'ക്ലബ്'),
          'Events' => tr(en: 'Events', ta: 'நிகழ்வுகள்', hi: 'इवेंट', ml: 'ഇവന്റുകൾ'),
          _ => tr(en: 'Achievements', ta: 'சாதனைகள்', hi: 'उपलब्धियां', ml: 'നേട്ടങ്ങൾ'),
        };
    return Padding(
      padding: const EdgeInsets.only(top: 38),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (int i = 0; i < _tabs.length; i++)
              GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: active == i ? AppColors.primary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_tabs[i].$2, size: 16,
                          color: active == i ? AppColors.primary : context.cTextSecondary),
                      const SizedBox(width: 6),
                      Text(label(_tabs[i].$1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active == i ? FontWeight.w800 : FontWeight.w600,
                            color: active == i ? AppColors.primary : context.cTextSecondary,
                          )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Filter chips ─────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final int active;
  final void Function(int) onSelect;
  const _FilterChips({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    String label(String en) => switch (en) {
          'All' => tr(en: 'All', ta: 'எல்லாம்', hi: 'सभी', ml: 'എല്ലാം'),
          'Popular' => tr(en: 'Popular', ta: 'பிரபலம்', hi: 'लोकप्रिय', ml: 'ജനപ്രിയം'),
          'Recent' => tr(en: 'Recent', ta: 'சமீபத்திய', hi: 'हाल', ml: 'സമീപകാലം'),
          _ => tr(en: 'Following', ta: 'பின்தொடர்', hi: 'फ़ॉलोइंग', ml: 'പിന്തുടരുന്നു'),
        };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _filters.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active == i ? AppColors.primary : context.cSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active == i ? AppColors.primary : context.cBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(_filters[i].$2, size: 14,
                            color: active == i ? Colors.white : context.cTextSecondary),
                        const SizedBox(width: 5),
                        Text(label(_filters[i].$1),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: active == i ? Colors.white : context.cText,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Post card ────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final Post post;
  final bool ta;
  const _PostCard({required this.post, required this.ta});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  Post get p => widget.post;

  Future<void> _toggleLike() async {
    setState(() {
      p.likedByMe = !p.likedByMe;
      p.likeCount += p.likedByMe ? 1 : -1;
    });
    try {
      final r = await FeedApi.toggleLike(p.id);
      if (!mounted) return;
      setState(() {
        p.likedByMe = r['liked'] as bool? ?? p.likedByMe;
        p.likeCount = (r['like_count'] as num?)?.toInt() ?? p.likeCount;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          p.likedByMe = !p.likedByMe;
          p.likeCount += p.likedByMe ? 1 : -1;
        });
      }
    }
  }

  Future<void> _toggleRepost() async {
    setState(() {
      p.repostedByMe = !p.repostedByMe;
      p.repostCount += p.repostedByMe ? 1 : -1;
    });
    try {
      final r = await FeedApi.toggleRepost(p.id);
      if (!mounted) return;
      setState(() {
        p.repostedByMe = r['reposted'] as bool? ?? p.repostedByMe;
        p.repostCount = (r['repost_count'] as num?)?.toInt() ?? p.repostCount;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          p.repostedByMe = !p.repostedByMe;
          p.repostCount += p.repostedByMe ? 1 : -1;
        });
      }
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        post: p,
        onAdded: () => setState(() => p.commentCount += 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        p.author.name.trim().isNotEmpty ? p.author.name.trim()[0].toUpperCase() : '?';
    final sourceLabel = p.isInstagram ? 'Instagram' : 'Thread';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cBorder),
        boxShadow: context.isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  backgroundImage:
                      (p.author.avatarUrl != null && p.author.avatarUrl!.isNotEmpty)
                          ? NetworkImage(_fullUrl(p.author.avatarUrl!))
                          : null,
                  child: (p.author.avatarUrl == null || p.author.avatarUrl!.isEmpty)
                      ? Text(initial, style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w800))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(p.author.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w800,
                                    fontSize: 14, color: context.cText)),
                          ),
                          if (p.author.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 15, color: Color(0xFF2563EB)),
                          ],
                          if (p.author.role != null) ...[
                            const SizedBox(width: 6),
                            _RoleBadge(role: p.author.role!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(_ago(p.createdAt, widget.ta),
                              style: TextStyle(fontSize: 11.5, color: context.cTextSecondary)),
                          Text('  ·  ', style: TextStyle(color: context.cTextSecondary)),
                          if (p.isInstagram)
                            const Icon(Icons.camera_alt, size: 11, color: Color(0xFFC13584)),
                          if (p.isInstagram) const SizedBox(width: 3),
                          Text(sourceLabel,
                              style: TextStyle(fontSize: 11.5, color: context.cTextSecondary)),
                          Text('  ·  🌐', style: TextStyle(fontSize: 11, color: context.cTextSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz, color: context.cTextSecondary),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          if (p.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(p.content,
                  style: TextStyle(fontSize: 14.5, height: 1.4, color: context.cText)),
            ),
          if (p.hashtags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: p.hashtags.map((h) => _Tag(text: h)).toList(),
              ),
            ),
          if (p.imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _PostImages(urls: p.imageUrls, isInstagram: p.isInstagram),
            ),
          Divider(height: 1, color: context.cBorder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                _Action(icon: p.likedByMe ? Icons.favorite : Icons.favorite_border,
                    color: p.likedByMe ? const Color(0xFFEF4444) : null,
                    label: '${p.likeCount}', onTap: _toggleLike),
                _Action(icon: Icons.mode_comment_outlined,
                    label: '${p.commentCount}', onTap: _openComments),
                _Action(icon: Icons.repeat_rounded,
                    color: p.repostedByMe ? AppColors.primary : null,
                    label: '${p.repostCount}', onTap: _toggleRepost),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.send_outlined, size: 19, color: context.cTextSecondary),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr(en: 'Sharing coming soon', ta: 'விரைவில்',
                        hi: 'जल्द', ml: 'ഉടൻ')),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'Admin' || role == 'Manager';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.primary.withOpacity(0.12) : context.cBorder.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(role,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: isAdmin ? AppColors.primary : context.cTextSecondary)),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('#$text',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
              color: AppColors.primary)),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color ?? context.cTextSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
                color: color ?? context.cTextSecondary)),
          ],
        ),
      ),
    );
  }
}

class _PostImages extends StatelessWidget {
  final List<String> urls;
  final bool isInstagram;
  const _PostImages({required this.urls, this.isInstagram = false});

  Widget _img(BuildContext context, String u, {double? h}) => Image.network(
        _fullUrl(u),
        fit: BoxFit.cover,
        height: h,
        width: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          height: h ?? 180, color: context.cBorder,
          child: Icon(Icons.broken_image_outlined, color: context.cTextSecondary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (urls.length == 1) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _img(context, urls.first, h: 230),
      );
    } else if (urls.length == 2) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(children: [
          Expanded(child: _img(context, urls[0], h: 170)),
          const SizedBox(width: 3),
          Expanded(child: _img(context, urls[1], h: 170)),
        ]),
      );
    } else {
      // Big left + 2x2 right, with "+N" overlay on the last cell.
      final right = urls.skip(1).take(4).toList();
      final extra = urls.length - 5;
      content = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 230,
          child: Row(
            children: [
              Expanded(flex: 3, child: _img(context, urls[0], h: 230)),
              const SizedBox(width: 3),
              Expanded(
                flex: 2,
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 3, crossAxisSpacing: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (int i = 0; i < right.length; i++)
                      Stack(fit: StackFit.expand, children: [
                        _img(context, right[i]),
                        if (i == right.length - 1 && extra > 0)
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: Text('+$extra',
                                style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.w800, fontSize: 18)),
                          ),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!isInstagram) return content;
    return Stack(children: [
      content,
      const Positioned(
        right: 8, bottom: 8,
        child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
      ),
    ]);
  }
}

// ── Comments sheet ───────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final Post post;
  final VoidCallback onAdded;
  const _CommentsSheet({required this.post, required this.onAdded});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  List<PostComment>? _comments;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await FeedApi.comments(widget.post.id);
      if (mounted) setState(() => _comments = c);
    } catch (_) {
      if (mounted) setState(() => _comments = const []);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SyncService.enqueueComment(widget.post.id, text);
      if (!mounted) return;
      
      final tempComment = PostComment(
        id: 'temp',
        authorName: 'You',
        content: text,
        createdAt: DateTime.now(),
      );
      
      setState(() {
        _comments = [...?_comments, tempComment];
        _sending = false;
        _controller.clear();
      });
      widget.onAdded();
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.cBorder,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text(tr(en: 'Comments', ta: 'கருத்துகள்', hi: 'टिप्पणियाँ', ml: 'അഭിപ്രായങ്ങൾ'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.cText)),
            const Divider(height: 20),
            Expanded(
              child: _comments == null
                  ? const Center(child: CircularProgressIndicator())
                  : _comments!.isEmpty
                      ? Center(child: Text(
                          tr(en: 'Be the first to comment', ta: 'முதல் கருத்தை இடுங்கள்',
                              hi: 'सबसे पहले टिप्पणी करें', ml: 'ആദ്യം അഭിപ്രായമിടൂ'),
                          style: TextStyle(color: context.cTextSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _comments!.length,
                          itemBuilder: (_, i) {
                            final c = _comments![i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(radius: 16,
                                      backgroundColor: AppColors.primary.withOpacity(0.15),
                                      child: Text(
                                          c.authorName.isNotEmpty
                                              ? c.authorName[0].toUpperCase() : '?',
                                          style: const TextStyle(color: AppColors.primary,
                                              fontWeight: FontWeight.w700, fontSize: 13))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.authorName, style: TextStyle(
                                            fontWeight: FontWeight.w700, fontSize: 13,
                                            color: context.cText)),
                                        const SizedBox(height: 2),
                                        Text(c.content, style: TextStyle(
                                            fontSize: 13.5, color: context.cText)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: tr(en: 'Write a comment…', ta: 'கருத்தை எழுதுங்கள்…',
                              hi: 'टिप्पणी लिखें…', ml: 'അഭിപ്രായം എഴുതുക…'),
                          filled: true,
                          fillColor: context.cBackground,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: context.cBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: context.cBorder),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
