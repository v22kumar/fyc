import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthSendOtpRequested extends AuthEvent {
  final String organizationId;
  final String phoneNumber;

  const AuthSendOtpRequested({
    required this.organizationId,
    required this.phoneNumber,
  });

  @override
  List<Object?> get props => [organizationId, phoneNumber];
}

class AuthVerifyOtpRequested extends AuthEvent {
  final String verificationId;
  final String otpCode;

  const AuthVerifyOtpRequested({
    required this.verificationId,
    required this.otpCode,
  });

  @override
  List<Object?> get props => [verificationId, otpCode];
}

class AuthRegisterRequested extends AuthEvent {
  final String organizationId;
  final String phoneNumber;
  final String registrationToken;
  final String? email;
  final String? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String role;
  final String fullNameTa;
  final String fullNameEn;
  final String preferredLanguage;

  const AuthRegisterRequested({
    required this.organizationId,
    required this.phoneNumber,
    required this.registrationToken,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.role = 'PUBLIC_CITIZEN',
    required this.fullNameTa,
    required this.fullNameEn,
    required this.preferredLanguage,
  });

  @override
  List<Object?> get props => [
        organizationId,
        phoneNumber,
        registrationToken,
        email,
        dateOfBirth,
        gender,
        bloodGroup,
        role,
        fullNameTa,
        fullNameEn,
        preferredLanguage,
      ];
}

class AuthGoogleSignInRequested extends AuthEvent {
  final String organizationId;
  /// The number typed before Google authentication. This is only a claim; it
  /// must never be used to identify the account or create the session.
  final String phoneNumber;

  const AuthGoogleSignInRequested({
    required this.organizationId,
    this.phoneNumber = '',
  });

  @override
  List<Object?> get props => [organizationId, phoneNumber];
}

class AuthGoogleSignInCancelled extends AuthEvent {
  const AuthGoogleSignInCancelled();
}

class AuthGoogleBrowserOpened extends AuthEvent {
  const AuthGoogleBrowserOpened();
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthSessionInvalid extends AuthEvent {
  const AuthSessionInvalid();
}
