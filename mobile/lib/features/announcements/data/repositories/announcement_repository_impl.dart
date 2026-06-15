import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/announcement_entity.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../datasources/announcement_datasource.dart';

class AnnouncementRepositoryImpl implements AnnouncementRepository {
  final AnnouncementDataSource _remote;
  AnnouncementRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<AnnouncementEntity>>> fetchAnnouncements({
    String? category,
  }) async {
    try {
      final announcements =
          await _remote.fetchAnnouncements(category: category);
      return Right(announcements);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AnnouncementEntity>> fetchAnnouncement(
    String id,
  ) async {
    try {
      final announcement = await _remote.fetchAnnouncement(id);
      return Right(announcement);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
