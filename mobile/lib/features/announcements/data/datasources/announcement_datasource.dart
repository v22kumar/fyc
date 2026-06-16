import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
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
      throw mapDioException(e);
    }
  }

  @override
  Future<AnnouncementModel> fetchAnnouncement(String id) async {
    try {
      final response =
          await _client.dio.get('${ApiConstants.announcements}/$id');
      return AnnouncementModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
