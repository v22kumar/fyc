import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/announcement_entity.dart';

abstract class AnnouncementRepository {
  Stream<Either<Failure, List<AnnouncementEntity>>> fetchAnnouncementsStream({
    String? category,
  });
  Future<Either<Failure, AnnouncementEntity>> fetchAnnouncement(String id);
}
