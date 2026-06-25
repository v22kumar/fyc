import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/event_datasource.dart';

class EventRepositoryImpl implements EventRepository {
  final EventDataSource _remote;
  EventRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<EventEntity>>> fetchEvents() async {
    try {
      final events = await _remote.fetchEvents();
      return Right(events);
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
}
