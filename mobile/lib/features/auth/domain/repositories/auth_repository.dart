import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';
import '../entities/otp_challenge.dart';

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

  /// [onBrowserOpened] fires if the sign-in has to leave the app for the
  /// phone's browser, so the screen can say so rather than spin in silence.
  Future<Either<Failure, GoogleAuthOutcome>> signInWithGoogle({
    required String organizationId,
    void Function()? onBrowserOpened,
  });

  /// Give up on a browser sign-in still being waited on.
  void cancelGoogleBrowserSignIn();

  Future<Either<Failure, UserEntity>> getMe();

  Future<void> logout();

  /// Best-effort: push registration must never block login.
  Future<void> registerFcmToken(String token);

  /// The one-time profile completion patch.
  Future<void> updateMyProfile(Map<String, dynamic> body);
}
