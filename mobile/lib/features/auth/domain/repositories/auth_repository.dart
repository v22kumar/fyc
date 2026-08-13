import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../entities/otp_challenge.dart';

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
  Future<Either<Failure, OtpChallenge>> sendOtp({
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
    required String registrationToken,
    String? email,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
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

  /// Google authenticates the account. [phoneNumber] is only a phone claim.
  /// OTP delivery/verification must never be required to return a session.
  Future<Either<Failure, GoogleAuthOutcome>> signInWithGoogle({
    required String organizationId,
    required String phoneNumber,
    void Function()? onBrowserOpened,
  });

  void cancelGoogleBrowserSignIn();

  Future<Either<Failure, UserEntity>> getMe();
  Future<void> logout();
  Future<void> registerFcmToken(String token);
  Future<void> updateMyProfile(Map<String, dynamic> body);
}
