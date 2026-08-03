import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/blood_donor_entity.dart';
import '../repositories/blood_donor_repository.dart';

class RegisterDonorUseCase {
  final BloodDonorRepository repository;
  RegisterDonorUseCase(this.repository);

  Future<Either<Failure, BloodDonorEntity>> call({
    required String bloodGroup,
    bool isAvailable = true,
    String? geographyId,
    DateTime? lastDonationDate,
    double? latitude,
    double? longitude,
    bool locationConsent = false,
    bool notifyOptIn = true,
  }) {
    if (bloodGroup.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Blood group is required')),
      );
    }
    return repository.registerAsDonor(
      bloodGroup: bloodGroup,
      isAvailable: isAvailable,
      geographyId: geographyId,
      lastDonationDate: lastDonationDate,
      latitude: latitude,
      longitude: longitude,
      locationConsent: locationConsent,
      notifyOptIn: notifyOptIn,
    );
  }
}
