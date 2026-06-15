import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/drive_entity.dart';
import '../repositories/green_repository.dart';

class FetchDrivesUseCase {
  final GreenRepository repository;
  FetchDrivesUseCase(this.repository);

  Future<Either<Failure, List<DriveEntity>>> call() =>
      repository.fetchDrives();
}
