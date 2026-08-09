import '../../data/models/feed_models.dart';

/// What the community feed can ask of the server — the seam the screens and
/// the offline outbox bind to, replacing a class of 13 static futures that
/// resolved a Dio from the service locator on every call.
abstract class FeedRepository {
  Future<List<Post>> list({
    String scope = 'all',
    String feed = 'recent',
    String? category,
    String? source,
    int limit = 20,
    int offset = 0,
  });

  /// The community *activity* feed (events, tournaments, issues, green).
  Future<List<Map<String, dynamic>>> activityFeed();

  Future<Post> create({
    required String content,
    required List<String> imageUrls,
    String? category,
    String? location,
    bool shareToInstagram = false,
    String? idempotencyKey,
  });

  Future<Map<String, dynamic>> toggleLike(String postId);
  Future<Map<String, dynamic>> toggleRepost(String postId);
  Future<List<String>> recentHashtags();
  Future<List<PostComment>> comments(String postId);
  Future<PostComment> addComment(String postId, String content,
      {String? idempotencyKey});
  Future<void> delete(String postId);
  Future<void> hide(String postId);
  Future<void> report(String postId, {String? reason});
  Future<void> blockUser(String userId);

  /// Uploads an image file and returns its URL (Cloudinary or local).
  Future<String> uploadImage(String filePath);
}
