import 'package:dio/dio.dart';

import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/safety_entities.dart';
import '../models/safety_models.dart';

/// The one place that talks to the server about safety.
abstract class SafetyDataSource {
  Future<SosIncident> raise(Map<String, dynamic> body);
  Future<SosIncident> load(String id);
  Future<SosIncident> post(String id, String action,
      [Map<String, dynamic>? body]);
  Future<List<SosSummary>> mine();
  Future<List<SosSummary>> live();
  Future<ResponderAlert> alert(String id);
  Future<List<SafetyContact>> contacts();
  Future<SafetyContact> addContact(Map<String, dynamic> body);
  Future<void> removeContact(String id);
  Future<SafetyContact> testContact(String id);
  Future<ResponderSettings> availability();
  Future<ResponderSettings> setAvailability(Map<String, dynamic> body);
}

class SafetyDataSourceImpl implements SafetyDataSource {
  SafetyDataSourceImpl(this._api);

  final ApiClient _api;

  static const _base = '/api/v1/safety';

  Map<String, dynamic> _map(Response r) => (r.data as Map).cast<String, dynamic>();

  List<Map<String, dynamic>> _list(Response r) => [
        for (final row in (r.data as List? ?? []))
          (row as Map).cast<String, dynamic>()
      ];

  @override
  Future<SosIncident> raise(Map<String, dynamic> body) async {
    try {
      return incidentFromJson(
          _map(await _api.dio.post<dynamic>('$_base/sos', data: body)));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<SosIncident> load(String id) async {
    try {
      return incidentFromJson(_map(await _api.dio.get<dynamic>('$_base/sos/$id')));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<SosIncident> post(String id, String action,
      [Map<String, dynamic>? body]) async {
    try {
      return incidentFromJson(_map(
          await _api.dio.post<dynamic>('$_base/sos/$id/$action', data: body ?? {})));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<SosSummary>> mine() async {
    try {
      return [
        for (final j in _list(await _api.dio.get<dynamic>('$_base/sos/mine')))
          summaryFromJson(j)
      ];
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<SosSummary>> live() async {
    try {
      return [
        for (final j in _list(await _api.dio.get<dynamic>('$_base/sos/live')))
          summaryFromJson(j)
      ];
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ResponderAlert> alert(String id) async {
    try {
      return alertFromJson(
          _map(await _api.dio.get<dynamic>('$_base/sos/$id/alert')));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<SafetyContact>> contacts() async {
    try {
      return [
        for (final j in _list(await _api.dio.get<dynamic>('$_base/contacts')))
          contactFromJson(j)
      ];
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<SafetyContact> addContact(Map<String, dynamic> body) async {
    try {
      return contactFromJson(
          _map(await _api.dio.post<dynamic>('$_base/contacts', data: body)));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<void> removeContact(String id) async {
    try {
      await _api.dio.delete<dynamic>('$_base/contacts/$id');
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<SafetyContact> testContact(String id) async {
    try {
      return contactFromJson(
          _map(await _api.dio.post<dynamic>('$_base/contacts/$id/test')));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ResponderSettings> availability() async {
    try {
      return settingsFromJson(
          _map(await _api.dio.get<dynamic>('$_base/availability')));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ResponderSettings> setAvailability(Map<String, dynamic> body) async {
    try {
      return settingsFromJson(
          _map(await _api.dio.put<dynamic>('$_base/availability', data: body)));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
