import 'package:dio/dio.dart';

import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/complaint_entities.dart';
import '../models/complaint_models.dart';

/// The one place that talks to the server about complaints.
abstract class ComplaintDataSource {
  Future<CallLadder> ladder(
      {required String category, String? geographyId, String? complaintId});
  Future<List<ComplaintSummary>> mine({bool includeClosed});
  Future<ComplaintState> load(String id);
  Future<ComplaintState> logCall(String id, Map<String, dynamic> body);
  Future<ComplaintDraft> draft(String id, Map<String, dynamic> body);
  Future<ComplaintState> post(String id, String action, [Map<String, dynamic>? body]);
  Future<void> suggestContact(String authorityId, Map<String, dynamic> body);
}

class ComplaintDataSourceImpl implements ComplaintDataSource {
  ComplaintDataSourceImpl(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/civic/complaints';

  Map<String, dynamic> _map(Response r) => (r.data as Map).cast<String, dynamic>();

  @override
  Future<CallLadder> ladder(
      {required String category,
      String? geographyId,
      String? complaintId}) async {
    try {
      final r = await _api.dio.get<dynamic>('/api/v1/civic/ladder', queryParameters: {
        'category': category,
        if (geographyId != null) 'geography_id': geographyId,
        // Which complaint this is for. The server builds the ladder from where
        // the thing actually is rather than from the member's home area, and
        // answers "not our district" when the two are far apart.
        if (complaintId != null) 'complaint_id': complaintId,
      });
      return ladderFromJson(_map(r));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<ComplaintSummary>> mine({bool includeClosed = true}) async {
    try {
      final r = await _api.dio.get<dynamic>(_base, queryParameters: {
        'include_closed': includeClosed,
      });
      return [
        for (final c in (r.data as List? ?? []))
          summaryFromJson((c as Map).cast<String, dynamic>())
      ];
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
  Future<void> suggestContact(
      String authorityId, Map<String, dynamic> body) async {
    try {
      await _api.dio.post<dynamic>(
          '/api/v1/civic/authorities/$authorityId/suggest-contact',
          data: body);
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
