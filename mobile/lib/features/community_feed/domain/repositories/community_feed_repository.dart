import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/feed_item_entity.dart';

abstract class CommunityFeedRepository {
  Stream<Either<Failure, List<CommunityFeedItemEntity>>> fetchFeedStream();
}
