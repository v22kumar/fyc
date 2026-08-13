/// Ephemeral phone claim captured before Google authentication.
///
/// It is not an identity credential. It is cleared by the network interceptor
/// after the corresponding Google request/result is handled.
class AuthGoogleContext {
  AuthGoogleContext._();

  static String? phoneNumber;
}
