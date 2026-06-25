import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/feed_item_entity.dart';
import '../../domain/repositories/community_feed_repository.dart';
import '../datasources/community_feed_datasource.dart';

class CommunityFeedRepositoryImpl implements CommunityFeedRepository {
  final CommunityFeedDataSource _remote;
  CommunityFeedRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<CommunityFeedItemEntity>>> fetchFeed() async {
    try {
      final feed = await _remote.fetchFeed();
      return Right(feed);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
