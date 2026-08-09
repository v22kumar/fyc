import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, VoidCallback;
import '../constants/api_constants.dart';
import '../storage/local_storage.dart';

class ApiClient {
  final Dio _dio;
  final LocalStorage _localStorage;

  /// Fired only when a 401 could NOT be recovered by refreshing (no/expired
  /// refresh token) — i.e. the session is truly over. Wired once in main.dart
  /// to log the user out and return them to login, the same
  /// decoupling pattern as LocalNotifications.onTapRoute: this networking
  /// layer must not import the router/feature layer directly (app_router.dart
  /// imports feature screens, which import service_locator.dart, which
  /// imports this file — a direct import here would cycle back).
  static VoidCallback? onSessionExpired;

  ApiClient(this._localStorage)
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(_AuthInterceptor(_localStorage));
    if (kDebugMode) {
      // Debug builds only — never log headers (strips Authorization/JWT) or
      // run in release/profile builds where logs may be captured by crash tools.
      _dio.interceptors.add(LogInterceptor(
        requestHeader: false,
        responseHeader: false,
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  final LocalStorage _storage;

  // A bare Dio (no interceptors) used to hit /auth/refresh and to replay the
  // original request — so neither recurses back through this interceptor.
  final Dio _bare = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    // Same timeouts as the primary client so a stalled refresh/replay can't
    // hold every concurrent 401 handler open indefinitely.
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  // Single-flight guard: concurrent 401s share ONE refresh call.
  Future<bool>? _refreshing;

  _AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getToken();
    final orgId = _storage.getOrgId() ?? ApiConstants.defaultOrgId;

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['X-Organization-ID'] = orgId;
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestHadToken = err.requestOptions.headers['Authorization'] != null;
    // Only the CREDENTIAL-ISSUING auth routes (and /refresh itself) return 401
    // for ordinary "wrong/expired credentials" — those must not trigger a
    // refresh/logout loop. Protected auth routes like /auth/users/me DO need the
    // refresh-and-replay recovery (it's the launch session check), so don't
    // blanket-exclude every /auth/ path.
    final p = err.requestOptions.path;
    final isCredentialRoute = p.contains('/auth/login') ||
        p.contains('/auth/otp') ||
        p.contains('/auth/register') ||
        p.contains('/auth/google') ||
        p.contains('/auth/refresh');
    if (err.response?.statusCode == 401 && requestHadToken && !isCredentialRoute) {
      // Access token expired mid-session. Silently mint a new one with the
      // refresh token and replay the original request, so the user stays signed
      // in instead of being bounced to login.
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        try {
          final newToken = await _storage.getToken();
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          final res = await _bare.fetch(opts);
          return handler.resolve(res);
        } catch (_) {
          // Replaying failed — fall through to the session-over path.
        }
      }
      // No/invalid refresh token, or refresh failed → the session is truly over.
      await _storage.clearToken();
      ApiClient.onSessionExpired?.call();
    }
    handler.next(err);
  }

  Future<bool> _refreshAccessToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    try {
      final rt = await _storage.getRefreshToken();
      if (rt == null || rt.isEmpty) return false;
      final res = await _bare.post(ApiConstants.authRefresh, data: {'refresh_token': rt});
      final data = res.data;
      final newAccess = (data is Map) ? data['access_token'] as String? : null;
      if (newAccess != null && newAccess.isNotEmpty) {
        await _storage.saveToken(newAccess);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
