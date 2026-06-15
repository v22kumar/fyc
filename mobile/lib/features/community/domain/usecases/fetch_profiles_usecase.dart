import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/community_profile_entity.dart';
import '../repositories/community_repository.dart';

class FetchProfilesUseCase {
  final CommunityRepository repository;
  FetchProfilesUseCase(this.repository);

  Future<Either<Failure, List<CommunityProfileEntity>>> call() {
    return repository.fetchProfiles();
  }
}
