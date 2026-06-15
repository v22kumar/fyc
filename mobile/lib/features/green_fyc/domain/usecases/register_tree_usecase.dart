import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/tree_entity.dart';
import '../repositories/green_repository.dart';

class RegisterTreeUseCase {
  final GreenRepository repository;
  RegisterTreeUseCase(this.repository);

  Future<Either<Failure, TreeEntity>> call({
    String? driveId,
    String? speciesTa,
    String? speciesEn,
    double? latitude,
    double? longitude,
    String? geographyId,
    required DateTime plantedDate,
    String? photoUrl,
    String? notes,
  }) =>
      repository.registerTree(
        driveId: driveId,
        speciesTa: speciesTa,
        speciesEn: speciesEn,
        latitude: latitude,
        longitude: longitude,
        geographyId: geographyId,
        plantedDate: plantedDate,
        photoUrl: photoUrl,
        notes: notes,
      );
}
