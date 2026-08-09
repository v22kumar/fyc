import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/community_profile_entity.dart';

abstract class CommunityRepository {
  Future<Either<Failure, List<CommunityProfileEntity>>> fetchProfiles();

  /// Raw roster rows for the members screen (it owns its own parsing).
  Future<List<dynamic>> fetchRoster();
}
