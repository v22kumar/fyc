import 'package:dio/dio.dart';
import 'failures.dart';

/// Single source of truth for translating transport/HTTP errors into typed
/// [Failure]s. Every data source should call this instead of hand-rolling
/// its own mapping, so status codes (403/404/409/429) are handled
/// consistently across features.
Failure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return const NetworkFailure();
    default:
      break;
  }

  final data = e.response?.data;
  // Only surface the server's `detail` when it's a clean human string (FastAPI
  // HTTPException). Validation (422) detail is a technical List, and 5xx detail
  // can leak internals — for those we ALWAYS use a friendly canned message so a
  // user never sees "422", "500", "ValidationError" or "SocketException".
  final rawDetail = data is Map ? data['detail'] : null;
  final rawMessage = data is Map ? data['message'] : null;
  final serverMsg = (rawDetail is String && rawDetail.trim().isNotEmpty)
      ? rawDetail
      : ((rawMessage is String && rawMessage.trim().isNotEmpty) ? rawMessage : null);

  switch (e.response?.statusCode) {
    case 401:
      return const AuthFailure('Your session has expired. Please sign in again.');
    case 403:
      return ForbiddenFailure(serverMsg ?? 'You don\'t have permission to do this.');
    case 404:
      return NotFoundFailure(serverMsg ?? 'We couldn\'t find what you were looking for.');
    case 409:
      return ConflictFailure(serverMsg ?? 'That already exists.');
    case 400:
      return ValidationFailure(serverMsg ?? 'Please check the details and try again.');
    case 422:
      // Never expose validation internals.
      return const ValidationFailure('Please check the details and try again.');
    case 429:
      return const RateLimitFailure('You\'re going a bit fast — please wait a moment and try again.');
  }

  final statusCode = e.response?.statusCode ?? 0;

  // 502/503 are the server telling us somebody ELSE failed — an SMS gateway
  // that refused the number, a provider that is down. It writes those messages
  // for members to read, and they are the only useful thing on the screen:
  //
  //   "We could not send your code by SMS, WhatsApp or email.
  //    Please ask an organizer to let you in."
  //
  // That was being replaced with "Something went wrong on our end. Please try
  // again in a moment." — which is wrong twice over. Nothing went wrong on our
  // end, and trying again in a moment will fail exactly the same way. A member
  // stood at a registration desk retrying a thing that could never work, with
  // no idea that an organiser could let them in.
  //
  // 500 keeps the canned message: an unhandled exception's detail is an
  // internal leak, not an explanation.
  if (statusCode == 502 || statusCode == 503) {
    return ServerFailure(serverMsg ??
        'A service we rely on is not answering. Please try again shortly.');
  }
  if (statusCode >= 500) {
    return const ServerFailure('Something went wrong on our end. Please try again in a moment.');
  }
  return const UnknownFailure('Something went wrong. Please try again.');
}
