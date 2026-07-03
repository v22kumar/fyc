import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../service_locator.dart';
import 'feed_models.dart';

/// Thin wrapper over the /posts + /media endpoints for the community feed.
class FeedApi {
  static Dio get _dio => sl<ApiClient>().dio;

  static Future<List<Post>> list({
    String scope = 'all',
    String feed = 'recent', // recent | popular | following
    String? category, // null/All = no filter
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _dio.get('/api/v1/posts', queryParameters: {
      'scope': scope,
      'feed': feed,
      if (category != null && category.isNotEmpty && category != 'All')
        'category': category,
      'limit': limit,
      'offset': offset,
    });
    final list = (res.data as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => Post.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  static Future<Post> create({
    required String content,
    required List<String> imageUrls,
    String? category,
    String? location,
    bool shareToInstagram = false,
  }) async {
    final res = await _dio.post('/api/v1/posts', data: {
      'content': content,
      'image_urls': imageUrls,
      if (category != null && category.isNotEmpty) 'category': category,
      if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
      'share_to_instagram': shareToInstagram,
    });
    return Post.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<Map<String, dynamic>> toggleLike(String postId) async {
    final res = await _dio.post('/api/v1/posts/$postId/like');
    return (res.data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> toggleRepost(String postId) async {
    final res = await _dio.post('/api/v1/posts/$postId/repost');
    return (res.data as Map).cast<String, dynamic>();
  }

  static Future<List<String>> recentHashtags() async {
    try {
      final res = await _dio.get('/api/v1/posts/hashtags');
      return ((res.data as List?) ?? const []).map((e) => e.toString()).toList();
    } catch (_) {
      return const ['#FYC', '#Community', '#Teamwork', '#GreenFYC', '#Event', '#Cricket'];
    }
  }

  static Future<List<PostComment>> comments(String postId) async {
    final res = await _dio.get('/api/v1/posts/$postId/comments');
    final list = (res.data as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => PostComment.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  static Future<PostComment> addComment(String postId, String content) async {
    final res = await _dio.post('/api/v1/posts/$postId/comments', data: {'content': content});
    return PostComment.fromJson((res.data as Map).cast<String, dynamic>());
  }

  static Future<void> delete(String postId) async {
    await _dio.delete('/api/v1/posts/$postId');
  }

  /// Uploads an image file and returns its URL (Cloudinary or local).
  static Future<String> uploadImage(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post('/api/v1/media/upload', data: form);
    return (res.data as Map)['url'] as String;
  }
}
