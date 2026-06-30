import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/api_constants.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../service_locator.dart';
import 'feed_api.dart';
import 'feed_models.dart';

String _fullUrl(String url) =>
    url.startsWith('http') ? url : '${ApiConstants.baseUrl}$url';

String _ago(DateTime d, bool ta) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return ta ? 'இப்போது' : 'just now';
  if (diff.inMinutes < 60) return ta ? '${diff.inMinutes} நிமி' : '${diff.inMinutes}m';
  if (diff.inHours < 24) return ta ? '${diff.inHours} மணி' : '${diff.inHours}h';
  if (diff.inDays < 7) return ta ? '${diff.inDays} நாள்' : '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool get _ta => sl<LocalStorage>().getLang() == 'ta';

  @override
  Widget build(BuildContext context) {
    final ta = _ta;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.cBackground,
        appBar: AppBar(
          title: Text(ta ? 'சமூக சுவர்' : 'Community Feed'),
          bottom: TabBar(
            tabs: [
              Tab(text: ta ? 'அனைத்தும்' : 'All'),
              Tab(text: ta ? 'என் இடுகைகள்' : 'My Posts'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await context.push<bool>('/feed/create');
            if (created == true) setState(() {}); // force lists to rebuild
          },
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.edit, color: Colors.white),
          label: Text(ta ? 'இடுகை' : 'Post',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: const TabBarView(
          children: [
            _FeedList(scope: 'all'),
            _FeedList(scope: 'mine'),
          ],
        ),
      ),
    );
  }
}

class _FeedList extends StatefulWidget {
  final String scope;
  const _FeedList({required this.scope});

  @override
  State<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<_FeedList>
    with AutomaticKeepAliveClientMixin {
  List<Post>? _posts;
  bool _error = false;

  bool get _ta => sl<LocalStorage>().getLang() == 'ta';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await FeedApi.list(scope: widget.scope);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _error = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ta = _ta;
    if (_posts == null && !_error) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: context.cTextSecondary),
            const SizedBox(height: 12),
            Text(ta ? 'சுவரை ஏற்ற முடியவில்லை' : "Couldn't load the feed"),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _load,
                child: Text(ta ? 'மீண்டும்' : 'Retry')),
          ],
        ),
      );
    }
    final posts = _posts!;
    if (posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 60),
            Image.asset('assets/illustrations/empty_feed.png',
                width: 160, height: 160,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.forum_outlined, size: 80, color: Colors.grey)),
            const SizedBox(height: 16),
            Center(
              child: Text(
                widget.scope == 'mine'
                    ? (ta ? 'நீங்கள் இன்னும் எதையும் பகிரவில்லை' : "You haven't posted yet")
                    : (ta ? 'இன்னும் இடுகைகள் இல்லை' : 'No posts yet'),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.cText),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                ta ? 'முதலில் பகிர்ந்து கொள்ளுங்கள்!' : 'Be the first to share something!',
                style: TextStyle(fontSize: 13, color: context.cTextSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: posts.length,
        itemBuilder: (_, i) => _PostCard(post: posts[i]),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Post post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool get _ta => sl<LocalStorage>().getLang() == 'ta';

  Post get p => widget.post;

  Future<void> _toggleLike() async {
    // optimistic
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
      // revert on failure
      if (mounted) {
        setState(() {
          p.likedByMe = !p.likedByMe;
          p.likeCount += p.likedByMe ? 1 : -1;
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
    final ta = _ta;
    final initial =
        p.author.name.trim().isNotEmpty ? p.author.name.trim()[0].toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.cBorder),
        boxShadow: context.isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  backgroundImage: (p.author.avatarUrl != null &&
                          p.author.avatarUrl!.isNotEmpty)
                      ? NetworkImage(_fullUrl(p.author.avatarUrl!))
                      : null,
                  child: (p.author.avatarUrl == null ||
                          p.author.avatarUrl!.isEmpty)
                      ? Text(initial,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.author.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: context.cText)),
                      Text(_ago(p.createdAt, ta),
                          style: TextStyle(
                              fontSize: 11.5, color: context.cTextSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (p.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(p.content,
                  style: TextStyle(
                      fontSize: 14.5, height: 1.4, color: context.cText)),
            ),
          if (p.imageUrls.isNotEmpty) _PostImages(urls: p.imageUrls),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                _action(
                  icon: p.likedByMe
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: p.likedByMe ? const Color(0xFFEF4444) : null,
                  label: '${p.likeCount}',
                  onTap: _toggleLike,
                ),
                _action(
                  icon: Icons.mode_comment_outlined,
                  label: '${p.commentCount}',
                  onTap: _openComments,
                ),
                _action(
                  icon: Icons.share_outlined,
                  label: ta ? 'பகிர்' : 'Share',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ta
                          ? 'பகிர்வு விரைவில் வரும்'
                          : 'Sharing coming soon'),
                    ));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
      {required IconData icon,
      required String label,
      Color? color,
      required VoidCallback onTap}) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19, color: color ?? context.cTextSecondary),
        label: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color ?? context.cTextSecondary)),
        style: TextButton.styleFrom(
            foregroundColor: context.cTextSecondary,
            padding: const EdgeInsets.symmetric(vertical: 8)),
      ),
    );
  }
}

class _PostImages extends StatelessWidget {
  final List<String> urls;
  const _PostImages({required this.urls});

  @override
  Widget build(BuildContext context) {
    Widget img(String u, {double? h}) => Image.network(
          _fullUrl(u),
          fit: BoxFit.cover,
          height: h,
          width: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            height: h ?? 180,
            color: context.cBorder,
            child: Icon(Icons.broken_image_outlined, color: context.cTextSecondary),
          ),
        );
    if (urls.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: img(urls.first, h: 220),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        children: urls.take(4).map((u) => img(u, h: 130)).toList(),
      ),
    );
  }
}

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

  bool get _ta => sl<LocalStorage>().getLang() == 'ta';

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
      final c = await FeedApi.addComment(widget.post.id, text);
      if (!mounted) return;
      setState(() {
        _comments = [...?_comments, c];
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
    final ta = _ta;
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.cBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Text(ta ? 'கருத்துகள்' : 'Comments',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.cText)),
            const Divider(height: 20),
            Expanded(
              child: _comments == null
                  ? const Center(child: CircularProgressIndicator())
                  : _comments!.isEmpty
                      ? Center(
                          child: Text(
                              ta
                                  ? 'முதல் கருத்தை இடுங்கள்'
                                  : 'Be the first to comment',
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
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        AppColors.primary.withOpacity(0.15),
                                    child: Text(
                                        c.authorName.isNotEmpty
                                            ? c.authorName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(c.authorName,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: context.cText)),
                                        const SizedBox(height: 2),
                                        Text(c.content,
                                            style: TextStyle(
                                                fontSize: 13.5,
                                                color: context.cText)),
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
                          hintText:
                              ta ? 'கருத்தை எழுதுங்கள்…' : 'Write a comment…',
                          filled: true,
                          fillColor: context.cBackground,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
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
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded,
                              color: AppColors.primary),
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
