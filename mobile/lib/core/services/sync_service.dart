import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../features/feed/feed_api.dart';

class SyncService {
  static const _boxName = 'outbox';
  
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static Future<void> enqueuePost({
    required String content,
    List<String> imageUrls = const [],
    List<String> localImagePaths = const [],
    String? category,
    String? location,
    bool shareToInstagram = false,
  }) async {
    final box = Hive.box(_boxName);
    final key = const Uuid().v4();
    final data = {
      'type': 'post',
      'idempotencyKey': key,
      'content': content,
      // Already-uploaded URLs (if any) plus local file paths that still need
      // uploading — the sync pass uploads the latter when the network is back,
      // so media posts survive offline instead of failing at compose time.
      'imageUrls': imageUrls,
      'localImagePaths': localImagePaths,
      'category': category,
      'location': location,
      'shareToInstagram': shareToInstagram,
    };
    await box.add(json.encode(data));
    _attemptSync();
  }

  static Future<void> enqueueComment(String postId, String content) async {
    final box = Hive.box(_boxName);
    final key = const Uuid().v4();
    final data = {
      'type': 'comment',
      'idempotencyKey': key,
      'postId': postId,
      'content': content,
    };
    await box.add(json.encode(data));
    _attemptSync();
  }

  static bool _isSyncing = false;
  static Future<void> _attemptSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final box = Hive.box(_boxName);
      final keysToRemove = [];
      for (final key in box.keys) {
        dynamic data;
        try {
          data = json.decode(box.get(key) as String);
        } catch (_) {
          // Malformed outbox entry — quarantine it so it can't block every
          // future sync pass, then move on to the next item.
          keysToRemove.add(key);
          continue;
        }
        try {
          if (data['type'] == 'post') {
            // Upload any queued local images now that we (presumably) have the
            // network. A failure here throws and the item stays queued for the
            // next pass — the post is never lost.
            final localPaths =
                List<String>.from(data['localImagePaths'] ?? const []);
            final uploaded = <String>[];
            for (final p in localPaths) {
              uploaded.add(await FeedApi.uploadImage(p));
            }
            final allUrls = <String>[
              ...List<String>.from(data['imageUrls'] ?? const []),
              ...uploaded,
            ];
            await FeedApi.create(
              content: data['content'],
              imageUrls: allUrls,
              category: data['category'],
              location: data['location'],
              shareToInstagram: (data['shareToInstagram'] ?? false) && allUrls.isNotEmpty,
              idempotencyKey: data['idempotencyKey'],
            );
          } else if (data['type'] == 'comment') {
            await FeedApi.addComment(
              data['postId'],
              data['content'],
              idempotencyKey: data['idempotencyKey'],
            );
          }
          keysToRemove.add(key);
        } catch (e) {
          break; // Stop syncing on first network failure
        }
      }
      for (final k in keysToRemove) {
        await box.delete(k);
      }
    } finally {
      _isSyncing = false;
    }
  }
  
  static void triggerSync() {
    _attemptSync();
  }
}
