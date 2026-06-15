import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/event_entity.dart';

abstract class EventRepository {
  Future<Either<Failure, List<EventEntity>>> fetchEvents();
  Future<Either<Failure, String>> checkinEvent(String eventId);
}
