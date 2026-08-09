import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/blood_donor_entity.dart';

abstract class BloodDonorRepository {
  Future<Either<Failure, List<BloodDonorEntity>>> searchDonors({
    String? bloodGroup,
    String? geographyId,
    bool nearby = false,
    bool availableOnly = true,
    String? source,
  });

  /// Donors ranked by real distance from a point.
  Future<Either<Failure, List<BloodDonorEntity>>> donorsNear({
    required double lat,
    required double lng,
    String? bloodGroup,
  });

  Future<Either<Failure, BloodDonorEntity>> registerAsDonor({
    required String bloodGroup,
    bool isAvailable = true,
    String? geographyId,
    DateTime? lastDonationDate,
    double? latitude,
    double? longitude,
    bool locationConsent = false,
    bool notifyOptIn = true,
  });

  Future<Either<Failure, Map<String, String>>> requestContact(String donorId);

  Future<Either<Failure, BloodDonorEntity>> updateAvailability({
    required String donorId,
    required bool isAvailable,
  });

  /// Taluk list for the directory filters (id + names, raw rows).
  Future<List<dynamic>> fetchTaluks();
}
