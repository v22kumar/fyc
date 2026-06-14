import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/membership_entity.dart';
import '../repositories/membership_repository.dart';

class GetMyCardUseCase {
  final MembershipRepository _repository;
  GetMyCardUseCase(this._repository);

  Future<Either<Failure, MembershipEntity>> call() =>
      _repository.getMyCard();
}
