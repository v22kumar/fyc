import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUserUseCase {
  final AuthRepository repository;
  RegisterUserUseCase(this.repository);

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<Either<Failure, UserEntity>> call({
    required String organizationId,
    required String phoneNumber,
    required String email,
    required String dateOfBirth,
    required String role,
    required String fullNameTa,
    required String fullNameEn,
    required String preferredLanguage,
  }) {
    if (fullNameTa.trim().isEmpty || fullNameEn.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Name in both Tamil and English is required')),
      );
    }
    if (!_emailRe.hasMatch(email.trim())) {
      return Future.value(
        const Left(ValidationFailure('Enter a valid email address')),
      );
    }
    if (dateOfBirth.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Date of birth is required')),
      );
    }
    return repository.registerUser(
      organizationId: organizationId,
      phoneNumber: phoneNumber,
      email: email.trim(),
      dateOfBirth: dateOfBirth.trim(),
      role: role,
      fullNameTa: fullNameTa.trim(),
      fullNameEn: fullNameEn.trim(),
      preferredLanguage: preferredLanguage,
    );
  }
}
