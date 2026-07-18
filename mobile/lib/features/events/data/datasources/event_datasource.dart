import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/event_model.dart';

abstract class EventDataSource {
  Future<List<EventModel>> fetchEvents();
  Future<List<String>> fetchEventRegistrants(String eventId);
  Future<Map<String, dynamic>> checkinEvent(String eventId);
  Future<EventModel> createEvent(Map<String, dynamic> body);
  Future<void> deleteEvent(String eventId);
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
      throw mapDioException(e);
    }
  }

  @override
  Future<List<String>> fetchEventRegistrants(String eventId) async {
    try {
      final response = await _client.dio
          .get('${ApiConstants.events}/$eventId/registrants');
      final data = response.data as Map<String, dynamic>;
      return (data['names'] as List<dynamic>).map((e) => e.toString()).toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<Map<String, dynamic>> checkinEvent(String eventId) async {
    try {
      final response = await _client.dio
          .post('${ApiConstants.events}/$eventId/checkin');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<EventModel> createEvent(Map<String, dynamic> body) async {
    try {
      final response = await _client.dio.post(ApiConstants.events, data: body);
      return EventModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _client.dio.delete('${ApiConstants.events}/$eventId');
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
