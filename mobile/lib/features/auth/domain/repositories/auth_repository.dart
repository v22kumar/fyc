import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

/// Result of a Google sign-in: either the member is logged in, or they're a
/// new account that must complete registration (phone + DOB) with their
/// Google name/email pre-filled.
sealed class GoogleAuthOutcome {}

class GoogleAuthSuccess extends GoogleAuthOutcome {
  final UserEntity user;
  GoogleAuthSuccess(this.user);
}

class GoogleAuthNeedsProfile extends GoogleAuthOutcome {
  final String email;
  final String fullName;
  GoogleAuthNeedsProfile({required this.email, required this.fullName});
}

abstract class AuthRepository {
  Future<Either<Failure, String>> sendOtp({
    required String organizationId,
    required String phoneNumber,
  });

  Future<Either<Failure, UserEntity>> verifyOtp({
    required String verificationId,
    required String otpCode,
  });

  Future<Either<Failure, UserEntity>> registerUser({
    required String organizationId,
    required String phoneNumber,
    required String email,
    required String dateOfBirth,
    required String role,
    required String fullNameTa,
    required String fullNameEn,
    required String preferredLanguage,
  });

  Future<Either<Failure, UserEntity>> loginWithPassword({
    required String organizationId,
    required String username,
    required String password,
  });

  Future<Either<Failure, GoogleAuthOutcome>> signInWithGoogle({
    required String organizationId,
  });

  Future<Either<Failure, UserEntity>> getMe();

  Future<void> logout();
}
