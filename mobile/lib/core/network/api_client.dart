import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, VoidCallback;
import '../constants/api_constants.dart';
import '../storage/local_storage.dart';

class ApiClient {
  final Dio _dio;
  final LocalStorage _localStorage;

  /// Fired when a request that carried a session token comes back 401 — the
  /// access token (60min lifetime, no refresh) has expired mid-session. Wired
  /// once in main.dart to log the user out and return them to login, the same
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

  _AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getToken();
    final orgId = await _storage.getOrgId() ?? ApiConstants.defaultOrgId;

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
    // Auth endpoints (otp/send, otp/verify, login/password, google, register)
    // return 401 for ordinary "wrong credentials" — that's not a session
    // expiry and must not trigger a forced logout while the user is mid-login.
    final isAuthEndpoint = err.requestOptions.path.startsWith('/api/v1/auth/');
    if (err.response?.statusCode == 401 && requestHadToken && !isAuthEndpoint) {
      // The 60-minute access token (no refresh mechanism) has expired mid-
      // session — every other request would silently keep failing until the
      // user force-closes and reopens the app. Clear it and bounce them back
      // to login instead of leaving the app in a broken-looking state.
      await _storage.clearToken();
      ApiClient.onSessionExpired?.call();
    }
    handler.next(err);
  }
}
