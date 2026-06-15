import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/announcement_model.dart';

abstract class AnnouncementDataSource {
  Future<List<AnnouncementModel>> fetchAnnouncements({String? category});
  Future<AnnouncementModel> fetchAnnouncement(String id);
}

class AnnouncementDataSourceImpl implements AnnouncementDataSource {
  final ApiClient _client;
  AnnouncementDataSourceImpl(this._client);

  @override
  Future<List<AnnouncementModel>> fetchAnnouncements({String? category}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.announcements,
        queryParameters: category != null ? {'category': category} : null,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<AnnouncementModel> fetchAnnouncement(String id) async {
    try {
      final response =
          await _client.dio.get('${ApiConstants.announcements}/$id');
      return AnnouncementModel.fromJson(response.data as Map<String, dynamic>);
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
