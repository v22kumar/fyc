import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/blood_donor_entity.dart';
import '../repositories/blood_donor_repository.dart';

class SearchDonorsUseCase {
  final BloodDonorRepository repository;
  SearchDonorsUseCase(this.repository);

  Future<Either<Failure, List<BloodDonorEntity>>> call({
    String? bloodGroup,
    String? geographyId,
    bool nearby = false,
    bool availableOnly = true,
  }) =>
      repository.searchDonors(
        bloodGroup: bloodGroup,
        geographyId: geographyId,
        nearby: nearby,
        availableOnly: availableOnly,
      );
}
