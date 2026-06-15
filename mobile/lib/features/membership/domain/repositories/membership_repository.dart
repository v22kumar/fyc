import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/membership_entity.dart';

abstract class MembershipRepository {
  Future<Either<Failure, MembershipEntity>> getMyCard();
}
