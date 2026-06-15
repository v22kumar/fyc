import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/contact_entity.dart';

abstract class ContactRepository {
  Future<Either<Failure, List<ContactEntity>>> fetchContacts({String? category});
}
