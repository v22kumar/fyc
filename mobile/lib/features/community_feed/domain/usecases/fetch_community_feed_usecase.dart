import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/feed_item_entity.dart';
import '../repositories/community_feed_repository.dart';

class FetchCommunityFeedUseCase {
  final CommunityFeedRepository _repository;
  FetchCommunityFeedUseCase(this._repository);

  Stream<Either<Failure, List<CommunityFeedItemEntity>>> call() {
    return _repository.fetchFeedStream();
  }
}
