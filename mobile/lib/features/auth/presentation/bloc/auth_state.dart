import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

/// OTP was sent — next step is verification
class AuthOtpSent extends AuthState {
  final String verificationId;
  final String phoneNumber;

  const AuthOtpSent({required this.verificationId, required this.phoneNumber});

  @override
  List<Object?> get props => [verificationId, phoneNumber];
}

/// OTP correct but user not registered — redirect to registration
class AuthNeedsRegistration extends AuthState {
  final String organizationId;
  final String phoneNumber;
  // Pre-fill from Google sign-in (null for the OTP path, where only the phone
  // is known). phoneNumber is empty for the Google path (collected in the form).
  final String? email;
  final String? fullName;

  const AuthNeedsRegistration({
    required this.organizationId,
    required this.phoneNumber,
    this.email,
    this.fullName,
  });

  @override
  List<Object?> get props => [organizationId, phoneNumber, email, fullName];
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthFailureState extends AuthState {
  final String message;
  const AuthFailureState(this.message);

  @override
  List<Object?> get props => [message];
}
