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
  final serverMsg = rawDetail is String && rawDetail.trim().isNotEmpty ? rawDetail : null;

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
  if (statusCode >= 500) {
    return const ServerFailure('Something went wrong on our end. Please try again in a moment.');
  }
  return const UnknownFailure('Something went wrong. Please try again.');
}
