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
  /// Everything below the name is optional now, and none of it is asked at the
  /// door. Date of birth, gender, blood group and role arrive later as profile
  /// prompts — see `features/profile/data/question_scheduler.dart`.
  final String? email;
  final String? dateOfBirth; // ISO yyyy-MM-dd
  final String? gender; // MALE / FEMALE / OTHER
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
  List<Object?> get props =>
      [organizationId, phoneNumber, registrationToken, email, dateOfBirth, gender, bloodGroup, role, fullNameTa, fullNameEn, preferredLanguage];
}

class AuthGoogleSignInRequested extends AuthEvent {
  final String organizationId;

  const AuthGoogleSignInRequested({required this.organizationId});

  @override
  List<Object?> get props => [organizationId];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
