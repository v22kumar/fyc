import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../constants/api_constants.dart';
import '../storage/local_storage.dart';

class ApiClient {
  final Dio _dio;
  final LocalStorage _localStorage;

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
}
