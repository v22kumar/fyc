import 'package:dartz/dartz.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../../../../core/error/failures.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/event_datasource.dart';
import '../models/event_model.dart';

class EventRepositoryImpl implements EventRepository {
  final EventDataSource _remote;
  EventRepositoryImpl(this._remote);

  @override
  Stream<Either<Failure, List<EventEntity>>> fetchEventsStream() async* {
    final boxName = 'events_cache';
    Box? box;
    bool servedCache = false;
    try {
      if (!Hive.isBoxOpen(boxName)) {
        box = await Hive.openBox(boxName);
      } else {
        box = Hive.box(boxName);
      }
      final cachedData = box.get('events');
      if (cachedData != null) {
        final list = (json.decode(cachedData) as List).map((e) => EventModel.fromJson(e)).toList();
        yield Right(list);
        servedCache = true;
      }
    } catch (_) {}

    try {
      final events = await _remote.fetchEvents();
      // Cache write is best-effort — a persistence failure must not turn a
      // successful fetch into an error.
      if (box != null) {
        try {
          final jsonString = json.encode(events.map((e) => e.toJson()).toList());
          await box.put('events', jsonString);
        } catch (_) {}
      }
      yield Right(events);
    } on Failure catch (f) {
      if (!servedCache) yield Left(f);
    } catch (e) {
      if (!servedCache) yield Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<String>>> fetchEventRegistrants(String eventId) async {
    try {
      final names = await _remote.fetchEventRegistrants(eventId);
      return Right(names);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, String>> checkinEvent(String eventId) async {
    try {
      final result = await _remote.checkinEvent(eventId);
      return Right(result['message'] as String? ?? 'Checked in');
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, String>> deleteEvent(String eventId) async {
    try {
      await _remote.deleteEvent(eventId);
      return const Right('Event deleted successfully');
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
