import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUserUseCase {
  final AuthRepository repository;
  RegisterUserUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String organizationId,
    required String phoneNumber,
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
    return repository.registerUser(
      organizationId: organizationId,
      phoneNumber: phoneNumber,
      role: role,
      fullNameTa: fullNameTa.trim(),
      fullNameEn: fullNameEn.trim(),
      preferredLanguage: preferredLanguage,
    );
  }
}
