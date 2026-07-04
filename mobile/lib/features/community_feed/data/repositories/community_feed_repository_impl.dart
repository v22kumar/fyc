import 'package:dartz/dartz.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../../../../core/error/failures.dart';
import '../../domain/entities/feed_item_entity.dart';
import '../../domain/repositories/community_feed_repository.dart';
import '../datasources/community_feed_datasource.dart';
import '../models/feed_item_model.dart';

class CommunityFeedRepositoryImpl implements CommunityFeedRepository {
  final CommunityFeedDataSource _remote;
  CommunityFeedRepositoryImpl(this._remote);

  @override
  Stream<Either<Failure, List<CommunityFeedItemEntity>>> fetchFeedStream() async* {
    final boxName = 'community_feed_cache';
    Box? box;
    bool servedCache = false;
    try {
      if (!Hive.isBoxOpen(boxName)) {
        box = await Hive.openBox(boxName);
      } else {
        box = Hive.box(boxName);
      }
      final cachedData = box.get('feed');
      if (cachedData != null) {
        final list = (json.decode(cachedData) as List).map((e) => CommunityFeedItemModel.fromJson(e)).toList();
        yield Right(list);
        servedCache = true;
      }
    } catch (_) {}

    try {
      final feed = await _remote.fetchFeed();
      // Cache write is best-effort — a persistence failure must not turn a
      // successful fetch into an error.
      if (box != null) {
        try {
          final jsonString = json.encode(feed.map((e) => e.toJson()).toList());
          await box.put('feed', jsonString);
        } catch (_) {}
      }
      yield Right(feed);
    } on Failure catch (f) {
      if (!servedCache) yield Left(f);
    } catch (e) {
      if (!servedCache) yield Left(ServerFailure());
    }
  }
}
