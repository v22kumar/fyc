import 'package:dio/dio.dart';
import '../../../../core/error/failures.dart';
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
      throw _map(e);
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
