import 'package:dartz/dartz.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../../../../core/error/failures.dart';
import '../../domain/entities/announcement_entity.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../datasources/announcement_datasource.dart';
import '../models/announcement_model.dart';

class AnnouncementRepositoryImpl implements AnnouncementRepository {
  final AnnouncementDataSource _remote;
  AnnouncementRepositoryImpl(this._remote);

  @override
  Stream<Either<Failure, List<AnnouncementEntity>>> fetchAnnouncementsStream({
    String? category,
  }) async* {
    final boxName = 'announcements_cache';
    Box? box;
    bool servedCache = false;
    try {
      if (!Hive.isBoxOpen(boxName)) {
        box = await Hive.openBox(boxName);
      } else {
        box = Hive.box(boxName);
      }
      final cachedData = box.get(category ?? 'ALL');
      if (cachedData != null) {
        final list = (json.decode(cachedData) as List).map((e) => AnnouncementModel.fromJson(e)).toList();
        yield Right(list);
        servedCache = true;
      }
    } catch (_) {}

    try {
      final announcements =
          await _remote.fetchAnnouncements(category: category);
      // Cache write is best-effort — a persistence failure must not turn a
      // successful fetch into an error.
      if (box != null) {
        try {
          final jsonString = json.encode(announcements.map((e) => e.toJson()).toList());
          await box.put(category ?? 'ALL', jsonString);
        } catch (_) {}
      }
      yield Right(announcements);
    } on Failure catch (f) {
      // Don't overwrite already-served cached data with a hard error when the
      // background refresh fails (e.g. user went offline).
      if (!servedCache) yield Left(f);
    } catch (e) {
      if (!servedCache) yield Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, AnnouncementEntity>> fetchAnnouncement(
    String id,
  ) async {
    try {
      final announcement = await _remote.fetchAnnouncement(id);
      return Right(announcement);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
