import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/event_entity.dart';

abstract class EventRepository {
  Stream<Either<Failure, List<EventEntity>>> fetchEventsStream();
  Future<Either<Failure, String>> checkinEvent(String eventId);
}
