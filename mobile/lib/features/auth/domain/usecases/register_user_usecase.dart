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
    String? email,
    String? dateOfBirth,
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
    final trimmedEmail = (email ?? '').trim();
    if (trimmedEmail.isNotEmpty && !_emailRe.hasMatch(trimmedEmail)) {
      return Future.value(
        const Left(ValidationFailure('Enter a valid email address')),
      );
    }
    // Date of birth is no longer required to open an account. It is asked
    // afterwards as a profile prompt, along with gender and blood group.
    return repository.registerUser(
      organizationId: organizationId,
      phoneNumber: phoneNumber,
      registrationToken: registrationToken,
      email: trimmedEmail,
      dateOfBirth: dateOfBirth?.trim(),
      gender: gender,
      bloodGroup: bloodGroup,
      role: role,
      fullNameTa: fullNameTa.trim(),
      fullNameEn: fullNameEn.trim(),
      preferredLanguage: preferredLanguage,
    );
  }
}
