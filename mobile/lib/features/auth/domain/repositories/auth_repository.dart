import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

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

  Future<Either<Failure, UserEntity>> signInWithGoogle({
    required String organizationId,
  });

  Future<Either<Failure, UserEntity>> getMe();

  Future<void> logout();
}
