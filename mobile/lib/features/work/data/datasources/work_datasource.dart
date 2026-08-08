import 'package:dio/dio.dart';

import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';

abstract class WorkDataSource {
  Future<List<dynamic>> categories();
  Future<List<dynamic>> search(Map<String, dynamic> params);
  Future<Map<String, dynamic>> listing(String id);
  Future<void> recordView(String id);
  Future<Map<String, dynamic>> create(Map<String, dynamic> body);
  Future<List<dynamic>> mine();
  Future<void> report(String id, Map<String, dynamic> body);
}

class WorkDataSourceImpl implements WorkDataSource {
  WorkDataSourceImpl(this._api);

  final ApiClient _api;
  static const _base = '/api/v1/work';

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<dynamic>> categories() => _guard(() async =>
      (await _api.dio.get<dynamic>('$_base/categories')).data as List? ?? []);

  @override
  Future<List<dynamic>> search(Map<String, dynamic> params) => _guard(() async =>
      (await _api.dio.get<dynamic>('$_base/listings', queryParameters: params))
          .data as List? ??
      []);

  @override
  Future<Map<String, dynamic>> listing(String id) => _guard(() async =>
      ((await _api.dio.get<dynamic>('$_base/listings/$id')).data as Map)
          .cast<String, dynamic>());

  @override
  Future<void> recordView(String id) =>
      _guard(() async => _api.dio.post<dynamic>('$_base/listings/$id/view'));

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) =>
      _guard(() async =>
          ((await _api.dio.post<dynamic>('$_base/listings', data: body)).data
                  as Map)
              .cast<String, dynamic>());

  @override
  Future<List<dynamic>> mine() => _guard(
      () async => (await _api.dio.get<dynamic>('$_base/my')).data as List? ?? []);

  @override
  Future<void> report(String id, Map<String, dynamic> body) => _guard(
      () async => _api.dio.post<dynamic>('$_base/listings/$id/report', data: body));
}
