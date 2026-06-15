import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/event_model.dart';

abstract class EventDataSource {
  Future<List<EventModel>> fetchEvents();
  Future<Map<String, dynamic>> checkinEvent(String eventId);
}

class EventDataSourceImpl implements EventDataSource {
  final ApiClient _client;
  EventDataSourceImpl(this._client);

  @override
  Future<List<EventModel>> fetchEvents() async {
    try {
      final response = await _client.dio.get(ApiConstants.events);
      final list = response.data as List<dynamic>;
      return list
          .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<Map<String, dynamic>> checkinEvent(String eventId) async {
    try {
      final response = await _client.dio
          .post('${ApiConstants.events}/$eventId/checkin');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Failure _map(DioException e) {
    if (e.type == DioExceptionType.connectionError) return const NetworkFailure();
    final detail = (e.response?.data as Map?)?['detail'] as String? ?? 'Error';
    if (e.response?.statusCode == 401) return AuthFailure(detail);
    return ServerFailure(detail);
  }
}
