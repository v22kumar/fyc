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
  // FastAPI validation errors return detail as a List, not a String.
  // Fall back to a user-readable message rather than the raw value.
  final rawDetail = data is Map ? data['detail'] : null;
  final detail = rawDetail is String ? rawDetail : 'Something went wrong (${e.response?.statusCode ?? 'offline'})';

  switch (e.response?.statusCode) {
    case 401:
      return AuthFailure(detail);
    case 403:
      return ForbiddenFailure(detail);
    case 404:
      return NotFoundFailure(detail);
    case 409:
      return ConflictFailure(detail);
    case 422:
      return ValidationFailure(detail);
    case 429:
      return RateLimitFailure(detail);
  }

  final statusCode = e.response?.statusCode ?? 0;
  if (statusCode >= 500) {
    return ServerFailure(detail);
  }
  return UnknownFailure(detail);
}
