import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/drive_entity.dart';
import '../../domain/entities/green_stats.dart';
import '../../domain/entities/tree_entity.dart';
import '../../domain/repositories/green_repository.dart';
import '../datasources/green_datasource.dart';

class GreenRepositoryImpl implements GreenRepository {
  final GreenDataSource _remote;
  GreenRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, GreenStats>> fetchStats() async {
    try {
      final stats = await _remote.fetchStats();
      return Right(stats);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DriveEntity>>> fetchDrives() async {
    try {
      final drives = await _remote.fetchDrives();
      return Right(drives);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, DriveEntity>> fetchDrive(String driveId) async {
    try {
      final drive = await _remote.fetchDrive(driveId);
      return Right(drive);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TreeEntity>>> fetchTrees({String? driveId}) async {
    try {
      final trees = await _remote.fetchTrees(driveId: driveId);
      return Right(trees);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadPhoto(String filePath) async {
    try {
      final url = await _remote.uploadPhoto(filePath);
      return Right(url);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
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
  }) async {
    try {
      final tree = await _remote.registerTree(
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
      return Right(tree);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
