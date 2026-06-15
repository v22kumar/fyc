import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/announcement_entity.dart';

abstract class AnnouncementRepository {
  Future<Either<Failure, List<AnnouncementEntity>>> fetchAnnouncements({
    String? category,
  });
  Future<Either<Failure, AnnouncementEntity>> fetchAnnouncement(String id);
}
