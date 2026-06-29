import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/blood_donor_entity.dart';
import '../../domain/repositories/blood_donor_repository.dart';
import '../datasources/blood_donor_datasource.dart';

class BloodDonorRepositoryImpl implements BloodDonorRepository {
  final BloodDonorDataSource _remote;

  BloodDonorRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<BloodDonorEntity>>> searchDonors({
    String? bloodGroup,
    String? geographyId,
    bool nearby = false,
    bool availableOnly = true,
  }) async {
    try {
      final donors = await _remote.searchDonors(
        bloodGroup: bloodGroup,
        geographyId: geographyId,
        nearby: nearby,
        availableOnly: availableOnly,
      );
      return Right(donors);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, BloodDonorEntity>> registerAsDonor({
    required String bloodGroup,
    bool isAvailable = true,
    String? geographyId,
    DateTime? lastDonationDate,
  }) async {
    try {
      final donor = await _remote.registerAsDonor(
        bloodGroup: bloodGroup,
        isAvailable: isAvailable,
        geographyId: geographyId,
        lastDonationDate: lastDonationDate?.toIso8601String().substring(0, 10),
      );
      return Right(donor);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, String>>> requestContact(
      String donorId) async {
    try {
      final info = await _remote.requestContact(donorId);
      return Right(info);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, BloodDonorEntity>> updateAvailability({
    required String donorId,
    required bool isAvailable,
  }) async {
    try {
      final donor = await _remote.updateAvailability(
        donorId: donorId,
        isAvailable: isAvailable,
      );
      return Right(donor);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
