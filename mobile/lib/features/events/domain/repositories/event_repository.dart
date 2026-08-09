import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/event_entity.dart';
import '../entities/public_registrant.dart';

abstract class EventRepository {
  /// Emits cache first (if present), then the network result.
  Stream<Either<Failure, List<EventEntity>>> fetchEventsStream();

  /// Names-only list of registered candidates (public-safe, no PII).
  Future<Either<Failure, List<PublicRegistrant>>> fetchEventRegistrants(String eventId);

  Future<Either<Failure, String>> checkinEvent(String eventId);
  Future<Either<Failure, String>> deleteEvent(String eventId);

  // One-shot form submissions; the callers own the try/catch + snackbar.
  Future<void> registerForEvent(String eventId, Map<String, dynamic> data);

  /// Full registration rows for the admin screen (name, mobile, gender…).
  Future<List<dynamic>> fetchRegistrationsAdmin(String eventId);
}
