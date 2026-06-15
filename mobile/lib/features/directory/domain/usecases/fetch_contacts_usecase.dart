import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/contact_entity.dart';
import '../repositories/contact_repository.dart';

class FetchContactsUseCase {
  final ContactRepository repository;
  FetchContactsUseCase(this.repository);

  Future<Either<Failure, List<ContactEntity>>> call({String? category}) =>
      repository.fetchContacts(category: category);
}
