import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/drive_entity.dart';
import '../entities/green_stats.dart';
import '../entities/tree_entity.dart';

abstract class GreenRepository {
  Future<Either<Failure, GreenStats>> fetchStats();
  Future<Either<Failure, List<DriveEntity>>> fetchDrives();
  Future<Either<Failure, DriveEntity>> fetchDrive(String driveId);
  Future<Either<Failure, List<TreeEntity>>> fetchTrees({String? driveId});
  Future<Either<Failure, TreeEntity>> registerTree({
    String? driveId,
    String? speciesTa,
    String? speciesEn,
    double? latitude,
    double? longitude,
    String? geographyId,
    required DateTime plantedDate,
    String? photoUrl,
    String? notes,
  });
}
