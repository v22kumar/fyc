/// Lightweight models for the community feed.

class PostAuthor {
  final String id;
  final String name;
  final String? avatarUrl;
  const PostAuthor({required this.id, required this.name, this.avatarUrl});

  factory PostAuthor.fromJson(Map<String, dynamic> j) => PostAuthor(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] as String?) ?? 'FYC Member',
        avatarUrl: j['avatar_url'] as String?,
      );
}

class Post {
  final String id;
  final PostAuthor author;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  int likeCount;
  int commentCount;
  bool likedByMe;

  Post({
    required this.id,
    required this.author,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: (j['id'] ?? '').toString(),
        author: PostAuthor.fromJson(
            (j['author'] as Map?)?.cast<String, dynamic>() ?? const {}),
        content: (j['content'] as String?) ?? '',
        imageUrls: ((j['image_urls'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        createdAt:
            DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
        likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
        likedByMe: j['liked_by_me'] as bool? ?? false,
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
