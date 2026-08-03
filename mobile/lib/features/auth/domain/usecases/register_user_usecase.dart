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
    required String registrationToken,
    required String email,
    required String dateOfBirth,
    String? gender,
    String? bloodGroup,
    required String role,
    required String fullNameTa,
    required String fullNameEn,
    required String preferredLanguage,
  }) {
    if (fullNameEn.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Name is required')),
      );
    }
    // Email is optional — only validate the format when one was entered.
    if (email.trim().isNotEmpty && !_emailRe.hasMatch(email.trim())) {
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
      registrationToken: registrationToken,
      email: email.trim(),
      dateOfBirth: dateOfBirth.trim(),
      gender: gender,
      bloodGroup: bloodGroup,
      role: role,
      fullNameTa: fullNameTa.trim(),
      fullNameEn: fullNameEn.trim(),
      preferredLanguage: preferredLanguage,
    );
  }
}
