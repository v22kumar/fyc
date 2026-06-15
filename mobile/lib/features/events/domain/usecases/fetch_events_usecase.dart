import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/event_entity.dart';
import '../repositories/event_repository.dart';

class FetchEventsUseCase {
  final EventRepository repository;
  FetchEventsUseCase(this.repository);

  Future<Either<Failure, List<EventEntity>>> call() =>
      repository.fetchEvents();
}
