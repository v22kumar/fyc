import 'user_model.dart';

class TokenModel {
  final String accessToken;
  final String tokenType;
  final UserModel user;

  const TokenModel({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) => TokenModel(
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// The two shapes `/auth/google` can return: a normal [token] for an existing
/// member, or a `needs_registration` signal (with Google's email/name to
/// pre-fill) for a brand-new account that must first supply phone + DOB.
class GoogleAuthResult {
  final TokenModel? token;
  final bool needsRegistration;
  final String? email;
  final String? fullName;

  const GoogleAuthResult({
    this.token,
    this.needsRegistration = false,
    this.email,
    this.fullName,
  });

  factory GoogleAuthResult.fromJson(Map<String, dynamic> json) {
    if (json['needs_registration'] == true) {
      return GoogleAuthResult(
        needsRegistration: true,
        email: json['email'] as String?,
        fullName: json['full_name'] as String?,
      );
    }
    return GoogleAuthResult(token: TokenModel.fromJson(json));
  }
}
