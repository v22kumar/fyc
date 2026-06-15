import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/photo_entity.dart';

abstract class GalleryRepository {
  Future<Either<Failure, List<PhotoEntity>>> fetchPhotos();
  Future<Either<Failure, List<PhotoEntity>>> fetchEventPhotos(String eventId);
}
