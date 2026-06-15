import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/announcement_entity.dart';
import '../repositories/announcement_repository.dart';

class FetchAnnouncementsUseCase {
  final AnnouncementRepository repository;
  FetchAnnouncementsUseCase(this.repository);

  Future<Either<Failure, List<AnnouncementEntity>>> call({String? category}) =>
      repository.fetchAnnouncements(category: category);
}
