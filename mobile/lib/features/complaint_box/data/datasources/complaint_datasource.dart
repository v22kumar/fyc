import 'package:dio/dio.dart';

import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/complaint_entities.dart';
import '../models/complaint_models.dart';

/// The one place that talks to the server about complaints.
abstract class ComplaintDataSource {
  Future<CallLadder> ladder({required String category, String? geographyId});
  Future<ComplaintState> load(String id);
  Future<ComplaintState> logCall(String id, Map<String, dynamic> body);
  Future<ComplaintDraft> draft(String id, Map<String, dynamic> body);
  Future<ComplaintState> post(String id, String action, [Map<String, dynamic>? body]);
}

class ComplaintDataSourceImpl implements ComplaintDataSource {
  ComplaintDataSourceImpl(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/civic/complaints';

  Map<String, dynamic> _map(Response r) => (r.data as Map).cast<String, dynamic>();

  @override
  Future<CallLadder> ladder({required String category, String? geographyId}) async {
    try {
      final r = await _api.dio.get<dynamic>('/api/v1/civic/ladder', queryParameters: {
        'category': category,
        if (geographyId != null) 'geography_id': geographyId,
      });
      return ladderFromJson(_map(r));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ComplaintState> load(String id) async {
    try {
      return stateFromJson(_map(await _api.dio.get<dynamic>('$_base/$id')));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ComplaintState> logCall(String id, Map<String, dynamic> body) =>
      post(id, 'calls', body);

  @override
  Future<ComplaintDraft> draft(String id, Map<String, dynamic> body) async {
    try {
      final r = await _api.dio.post<dynamic>('$_base/$id/draft', data: body);
      return draftFromJson(_map(r));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ComplaintState> post(String id, String action,
      [Map<String, dynamic>? body]) async {
    try {
      final r = await _api.dio.post<dynamic>('$_base/$id/$action', data: body ?? {});
      return stateFromJson(_map(r));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
