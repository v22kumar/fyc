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
      }
    } catch (_) {}

    try {
      final announcements =
          await _remote.fetchAnnouncements(category: category);
      if (box != null) {
        final jsonString = json.encode(announcements.map((e) => e.toJson()).toList());
        await box.put(category ?? 'ALL', jsonString);
      }
      yield Right(announcements);
    } on Failure catch (f) {
      yield Left(f);
    } catch (e) {
      yield Left(ServerFailure());
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
