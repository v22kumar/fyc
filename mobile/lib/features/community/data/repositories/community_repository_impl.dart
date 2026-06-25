import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/community_profile_entity.dart';
import '../../domain/repositories/community_repository.dart';
import '../datasources/community_datasource.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  final CommunityDataSource _remote;
  CommunityRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<CommunityProfileEntity>>> fetchProfiles() async {
    try {
      final profiles = await _remote.fetchProfiles();
      return Right(profiles);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
