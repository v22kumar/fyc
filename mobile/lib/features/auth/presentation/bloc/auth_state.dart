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

/// Google sign-in has left the app for the phone's browser.
///
/// This is a different thing from AuthLoading and has to look different. The
/// browser road can take minutes — the member is choosing an account, finding a
/// password, reading an error — and when Google refuses the request outright it
/// never redirects back, so no signal ever arrives to end the wait. A spinner
/// with no words is indistinguishable from a frozen button, and that is exactly
/// what it was mistaken for. So: say where they are, and offer a way out.
class AuthGoogleInBrowser extends AuthState {
  const AuthGoogleInBrowser();
}

/// OTP was sent — next step is verification
class AuthOtpSent extends AuthState {
  final String verificationId;
  final String phoneNumber;

  /// Which channel actually carried the code: sms, whatsapp, email or log.
  ///
  /// The server walks a ladder — Twilio SMS, then WhatsApp, then email — so
  /// the answer is not knowable in advance. Telling a member to check their
  /// messages when the code went to WhatsApp looks, from where they are
  /// standing, exactly like nothing having been sent.
  final String? channel;

  const AuthOtpSent({
    required this.verificationId,
    required this.phoneNumber,
    this.channel,
  });

  @override
  List<Object?> get props => [verificationId, phoneNumber, channel];
}

/// OTP correct but user not registered — redirect to registration
class AuthNeedsRegistration extends AuthState {
  final String organizationId;
  final String phoneNumber;
  final String? registrationToken;
  // Pre-fill from Google sign-in (null for the OTP path, where only the phone
  // is known). phoneNumber is empty for the Google path (collected in the form).
  final String? email;
  final String? fullName;

  const AuthNeedsRegistration({
    required this.organizationId,
    required this.phoneNumber,
    this.registrationToken,
    this.email,
    this.fullName,
  });

  @override
  List<Object?> get props => [organizationId, phoneNumber, registrationToken, email, fullName];
}

/// A brand-new Google account was verified, but we still need a verified phone
/// before creating the account (industry-standard: Google gives identity + name
/// + email; a phone is collected and OTP-verified to finish). The login screen
/// switches to the phone step with the Google name/email carried through.
class AuthGoogleNeedsPhone extends AuthState {
  final String email;
  final String fullName;
  const AuthGoogleNeedsPhone({required this.email, required this.fullName});

  @override
  List<Object?> get props => [email, fullName];
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
