import 'package:dio/dio.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/photo_model.dart';

abstract class GalleryDataSource {
  Future<List<PhotoModel>> fetchPhotos();
  Future<List<PhotoModel>> fetchEventPhotos(String eventId);
}

class GalleryDataSourceImpl implements GalleryDataSource {
  final ApiClient _client;
  GalleryDataSourceImpl(this._client);

  static const String _gallery = '/api/v1/gallery';

  @override
  Future<List<PhotoModel>> fetchPhotos() async {
    try {
      final response = await _client.dio.get(_gallery);
      final list = response.data as List<dynamic>;
      return list
          .map((e) => PhotoModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<PhotoModel>> fetchEventPhotos(String eventId) async {
    try {
      final response = await _client.dio.get('$_gallery/events/$eventId');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => PhotoModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
