import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/repositories/contact_repository.dart';
import '../datasources/contact_datasource.dart';

class ContactRepositoryImpl implements ContactRepository {
  final ContactDataSource _remote;
  ContactRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<ContactEntity>>> fetchContacts(
      {String? category}) async {
    try {
      final contacts = await _remote.fetchContacts(category: category);
      return Right(contacts);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
