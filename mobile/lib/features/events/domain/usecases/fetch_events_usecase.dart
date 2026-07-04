import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/event_entity.dart';
import '../repositories/event_repository.dart';

class FetchEventsUseCase {
  final EventRepository _repository;
  FetchEventsUseCase(this._repository);

  Stream<Either<Failure, List<EventEntity>>> call() {
    return _repository.fetchEventsStream();
  }
}
