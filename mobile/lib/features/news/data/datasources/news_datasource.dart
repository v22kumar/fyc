import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/news_item_model.dart';

abstract class NewsDataSource {
  Future<List<NewsItemModel>> fetchTop({int limit = 10});
  Future<List<NewsItemModel>> fetchIndia({int limit = 5});
  Future<List<NewsItemModel>> fetchJobs({int limit = 4});
}

class NewsDataSourceImpl implements NewsDataSource {
  final ApiClient _client;
  NewsDataSourceImpl(this._client);

  Future<List<NewsItemModel>> _fetchFrom(String url, int limit) async {
    try {
      final response = await _client.dio.get(
        url,
        queryParameters: {'limit': limit},
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => NewsItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<NewsItemModel>> fetchTop({int limit = 10}) =>
      _fetchFrom(ApiConstants.newsTop, limit);

  @override
  Future<List<NewsItemModel>> fetchIndia({int limit = 5}) =>
      _fetchFrom(ApiConstants.newsIndia, limit);

  @override
  Future<List<NewsItemModel>> fetchJobs({int limit = 4}) =>
      _fetchFrom(ApiConstants.newsJobs, limit);
}
