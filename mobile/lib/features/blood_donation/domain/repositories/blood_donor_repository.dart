import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/blood_donor_entity.dart';

abstract class BloodDonorRepository {
  Future<Either<Failure, List<BloodDonorEntity>>> searchDonors({
    String? bloodGroup,
    bool availableOnly = true,
  });

  Future<Either<Failure, BloodDonorEntity>> registerAsDonor({
    required String bloodGroup,
    bool isAvailable = true,
    String? geographyId,
    DateTime? lastDonationDate,
  });

  Future<Either<Failure, Map<String, String>>> requestContact(String donorId);

  Future<Either<Failure, BloodDonorEntity>> updateAvailability({
    required String donorId,
    required bool isAvailable,
  });
}
