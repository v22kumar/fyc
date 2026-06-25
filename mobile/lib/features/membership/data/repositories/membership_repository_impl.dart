import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/membership_entity.dart';
import '../../domain/repositories/membership_repository.dart';
import '../datasources/membership_datasource.dart';

class MembershipRepositoryImpl implements MembershipRepository {
  final MembershipDataSource _remote;
  MembershipRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, MembershipEntity>> getMyCard() async {
    try {
      final card = await _remote.getMyCard();
      return Right(card);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
