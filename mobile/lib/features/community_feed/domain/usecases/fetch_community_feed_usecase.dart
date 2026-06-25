import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/feed_item_entity.dart';
import '../repositories/community_feed_repository.dart';

class FetchCommunityFeedUseCase {
  final CommunityFeedRepository repository;
  FetchCommunityFeedUseCase(this.repository);

  Future<Either<Failure, List<CommunityFeedItemEntity>>> call() {
    return repository.fetchFeed();
  }
}
