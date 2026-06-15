import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/community_profile_entity.dart';

abstract class CommunityRepository {
  Future<Either<Failure, List<CommunityProfileEntity>>> fetchProfiles();
}
