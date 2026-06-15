import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/photo_entity.dart';
import '../repositories/gallery_repository.dart';

class FetchPhotosUseCase {
  final GalleryRepository repository;
  FetchPhotosUseCase(this.repository);

  Future<Either<Failure, List<PhotoEntity>>> call() => repository.fetchPhotos();
}
