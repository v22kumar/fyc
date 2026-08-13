import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, VoidCallback;
import '../constants/api_constants.dart';
import '../storage/local_storage.dart';
import '../../features/auth/presentation/auth_google_context.dart';

class ApiClient {
  final Dio _dio;
  final LocalStorage _localStorage;
  static VoidCallback? onSessionExpired;

  ApiClient(this._localStorage)
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(_AuthInterceptor(_localStorage));
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(requestHeader: false, responseHeader: false, requestBody: true, responseBody: true));
    }
  }

  Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  final LocalStorage _storage;
  final Dio _bare = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));
  Future<bool>? _refreshing;
  _AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getToken();
    final orgId = _storage.getOrgId() ?? ApiConstants.defaultOrgId;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    options.headers['X-Organization-ID'] = orgId;
    handler.next(options);
  }

  @override
  Future<void> onResponse(Response response, ResponseInterceptorHandler handler) async {
    final path = response.requestOptions.path;
    final isGoogleSession = path.endsWith('/auth/google') || path.endsWith('/auth/google/browser/result');
    final phone = AuthGoogleContext.phoneNumber;

    if (isGoogleSession && phone != null && phone.isNotEmpty) {
      AuthGoogleContext.phoneNumber = null;
      final data = response.data;
      final hasSession = data is Map && (data['access_token'] as String?)?.isNotEmpty == true;
      final readyResult = data is Map && data['status'] == 'ready' && data['result'] is Map && ((data['result'] as Map)['access_token'] as String?)?.isNotEmpty == true;
      if (hasSession || readyResult) {
        try {
          final claimToken = hasSession ? data['access_token'] as String : (data['result'] as Map)['access_token'] as String;
          await _bare.post(
            '/api/v1/auth/google/claim-phone',
            data: {'phone_number': phone},
            options: Options(headers: {
              'Authorization': 'Bearer $claimToken',
              'X-Organization-ID': _storage.getOrgId() ?? ApiConstants.defaultOrgId,
            }),
          );
        } catch (_) {
          // Google authentication remains successful. Phone proof can be retried later.
        }
      }
    }
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final p = err.requestOptions.path;
    // A failed native Google attempt must not leave the previous phone claim
    // context attached to a later unrelated request. Browser polling keeps the
    // context because transient poll failures are expected.
    if (p.endsWith('/auth/google')) {
      AuthGoogleContext.phoneNumber = null;
    }

    final requestHadToken = err.requestOptions.headers['Authorization'] != null;
    final isCredentialRoute = p.contains('/auth/login') || p.contains('/auth/otp') || p.contains('/auth/register') || p.contains('/auth/google') || p.contains('/auth/refresh');
    if (err.response?.statusCode == 401 && requestHadToken && !isCredentialRoute) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        try {
          final newToken = await _storage.getToken();
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          final res = await _bare.fetch(opts);
          return handler.resolve(res);
        } catch (_) {}
      }
      await _storage.clearToken();
      ApiClient.onSessionExpired?.call();
    }
    handler.next(err);
  }

  Future<bool> _refreshAccessToken() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

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
    } catch (_) { return false; }
  }
}
