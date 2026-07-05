import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../features/feed/feed_api.dart';

class SyncService {
  static const _boxName = 'outbox';
  static const _mediaDir = 'outbox_media';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  /// Copy a picked image into app-persistent storage. image_picker returns temp
  /// cache paths the OS may purge before we get to sync, so a queued post must
  /// own a durable copy or it would fail forever after an app restart.
  static Future<String?> _persist(String srcPath) async {
    try {
      final src = File(srcPath);
      if (!await src.exists()) return null;
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/$_mediaDir');
      if (!await dir.exists()) await dir.create(recursive: true);
      final ext = srcPath.contains('.') ? srcPath.split('.').last : 'jpg';
      final dest = '${dir.path}/${const Uuid().v4()}.$ext';
      await src.copy(dest);
      return dest;
    } catch (_) {
      return null;
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
    // Persist picked images up front so the queued item owns durable files.
    final persisted = <String>[];
    for (final p in localImagePaths) {
      final d = await _persist(p);
      if (d != null) persisted.add(d);
    }
    final box = Hive.box(_boxName);
    final key = const Uuid().v4();
    final data = {
      'type': 'post',
      'idempotencyKey': key,
      'content': content,
      // Already-uploaded URLs (if any) plus durable local file paths that still
      // need uploading — the sync pass uploads the latter when the network is
      // back, so media posts survive offline (and restarts) instead of failing.
      'imageUrls': imageUrls,
      'localImagePaths': persisted,
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

        if (data['type'] == 'post') {
          final done = await _syncPost(box, key, data);
          if (done == _ItemResult.remove) {
            keysToRemove.add(key);
          } else if (done == _ItemResult.retryLater) {
            break; // transient failure — stop the pass, keep this + later items
          }
          // _ItemResult.skip → leave item, continue to next
        } else if (data['type'] == 'comment') {
          try {
            await FeedApi.addComment(
              data['postId'],
              data['content'],
              idempotencyKey: data['idempotencyKey'],
            );
            keysToRemove.add(key);
          } catch (_) {
            break; // transient network failure
          }
        } else {
          keysToRemove.add(key); // unknown type — quarantine
        }
      }
      for (final k in keysToRemove) {
        await box.delete(k);
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Returns how the caller should treat this post item.
  static Future<_ItemResult> _syncPost(Box box, dynamic key, Map data) async {
    final localPaths = List<String>.from(data['localImagePaths'] ?? const []);
    final alreadyUploaded = List<String>.from(data['imageUrls'] ?? const []);
    final uploaded = <String>[];
    final consumed = <String>[];

    for (final p in localPaths) {
      if (!await File(p).exists()) {
        // The durable copy is gone (shouldn't normally happen) — skip this one
        // file rather than block the whole outbox forever.
        continue;
      }
      try {
        uploaded.add(await FeedApi.uploadImage(p));
        consumed.add(p);
      } catch (_) {
        // Network/server hiccup — retry the whole item on the next pass. Persist
        // what we've uploaded so far so we don't re-upload it next time.
        if (uploaded.isNotEmpty) {
          data['imageUrls'] = [...alreadyUploaded, ...uploaded];
          data['localImagePaths'] =
              localPaths.where((x) => !consumed.contains(x)).toList();
          await box.put(key, json.encode(data));
          await _deleteFiles(consumed);
        }
        return _ItemResult.retryLater;
      }
    }

    final allUrls = <String>[...alreadyUploaded, ...uploaded];
    final content = (data['content'] as String?) ?? '';
    if (content.trim().isEmpty && allUrls.isEmpty) {
      // Nothing left to post (e.g. every image file was lost) — quarantine.
      await _deleteFiles(consumed);
      return _ItemResult.remove;
    }

    try {
      await FeedApi.create(
        content: content,
        imageUrls: allUrls,
        category: data['category'],
        location: data['location'],
        shareToInstagram: (data['shareToInstagram'] ?? false) && allUrls.isNotEmpty,
        idempotencyKey: data['idempotencyKey'],
      );
    } catch (_) {
      // Persist upload progress so a create retry doesn't re-upload the images.
      data['imageUrls'] = allUrls;
      data['localImagePaths'] = <String>[];
      await box.put(key, json.encode(data));
      await _deleteFiles(consumed);
      return _ItemResult.retryLater;
    }
    await _deleteFiles(consumed);
    return _ItemResult.remove;
  }

  static Future<void> _deleteFiles(List<String> paths) async {
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  static void triggerSync() {
    _attemptSync();
  }
}

enum _ItemResult { remove, retryLater, skip }
