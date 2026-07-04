import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/announcement_entity.dart';
import '../repositories/announcement_repository.dart';

class FetchAnnouncementsUseCase {
  final AnnouncementRepository _repository;
  FetchAnnouncementsUseCase(this._repository);

  Stream<Either<Failure, List<AnnouncementEntity>>> call({String? category}) {
    return _repository.fetchAnnouncementsStream(category: category);
  }
}
