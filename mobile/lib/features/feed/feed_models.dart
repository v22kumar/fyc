/// Lightweight models for the community feed.

class PostAuthor {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? role;      // Admin / Manager / Member / Volunteer
  final bool verified;
  const PostAuthor({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.role,
    this.verified = false,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> j) => PostAuthor(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] as String?) ?? 'FYC Member',
        avatarUrl: j['avatar_url'] as String?,
        role: j['role'] as String?,
        verified: j['verified'] as bool? ?? false,
      );
}

class Post {
  final String id;
  final PostAuthor author;
  final String content;
  final List<String> imageUrls;
  final String? category;
  final String source; // "thread" | "instagram"
  final String? location;
  final DateTime createdAt;
  int likeCount;
  int commentCount;
  int repostCount;
  bool likedByMe;
  bool repostedByMe;

  Post({
    required this.id,
    required this.author,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    this.category,
    this.source = 'thread',
    this.location,
    this.repostCount = 0,
    this.repostedByMe = false,
  });

  bool get isInstagram => source == 'instagram';

  /// Hashtags parsed from the post text, for chip display.
  List<String> get hashtags {
    final re = RegExp(r'#(\w+)');
    return re.allMatches(content).map((m) => m.group(1)!).toList();
  }

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: (j['id'] ?? '').toString(),
        author: PostAuthor.fromJson(
            (j['author'] as Map?)?.cast<String, dynamic>() ?? const {}),
        content: (j['content'] as String?) ?? '',
        imageUrls: ((j['image_urls'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        category: j['category'] as String?,
        source: (j['source'] as String?) ?? 'thread',
        location: j['location'] as String?,
        createdAt:
            DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
        likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
        repostCount: (j['repost_count'] as num?)?.toInt() ?? 0,
        likedByMe: j['liked_by_me'] as bool? ?? false,
        repostedByMe: j['reposted_by_me'] as bool? ?? false,
      );
}

class PostComment {
  final String id;
  final String authorName;
  final String content;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> j) => PostComment(
        id: (j['id'] ?? '').toString(),
        authorName: (j['author_name'] as String?) ?? 'FYC Member',
        content: (j['content'] as String?) ?? '',
        createdAt:
            DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );
}
