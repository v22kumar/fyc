import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

/// 5xx or unparseable server responses.
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'We couldn\'t complete your request right now. Please try again later.']);
}

/// No connectivity / DNS / timeout at the transport layer.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'We couldn\'t reach the network. Please check your internet connection.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'We couldn\'t load this right now.']);
}

/// 401 — missing/expired/invalid token. Should trigger logout/re-auth.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Please log in again to continue.']);
}

/// 403 — authenticated but not permitted (role or cross-tenant denial).
class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = 'You don\'t have permission to do this.']);
}

/// 404 — requested resource does not exist (or not in this tenant).
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'We couldn\'t find what you were looking for.']);
}

/// 400/422 — request rejected due to invalid input.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// 409 — conflicts with existing state (e.g. duplicate registration).
class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

/// 429 — rate limited, e.g. OTP requests.
class RateLimitFailure extends Failure {
  const RateLimitFailure([super.message = 'Too many requests. Please wait a moment and try again.']);
}

/// Anything else unexpected (parsing errors, unhandled status codes).
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something unexpected happened. Please try again.']);
}
