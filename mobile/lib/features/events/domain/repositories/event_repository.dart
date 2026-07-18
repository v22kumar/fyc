import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/event_entity.dart';

abstract class EventRepository {
  /// Emits cache first (if present), then the network result.
  Stream<Either<Failure, List<EventEntity>>> fetchEventsStream();

  /// Names-only list of registered candidates (public-safe, no PII).
  Future<Either<Failure, List<String>>> fetchEventRegistrants(String eventId);

  Future<Either<Failure, String>> checkinEvent(String eventId);
  Future<Either<Failure, String>> deleteEvent(String eventId);
}
