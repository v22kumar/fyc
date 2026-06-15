import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../datasources/gallery_datasource.dart';

class GalleryRepositoryImpl implements GalleryRepository {
  final GalleryDataSource _remote;
  GalleryRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<PhotoEntity>>> fetchPhotos() async {
    try {
      final photos = await _remote.fetchPhotos();
      return Right(photos);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PhotoEntity>>> fetchEventPhotos(
      String eventId) async {
    try {
      final photos = await _remote.fetchEventPhotos(eventId);
      return Right(photos);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
