import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/news_item_model.dart';

abstract class NewsDataSource {
  Future<List<NewsItemModel>> fetchTop({int limit = 10});
}

class NewsDataSourceImpl implements NewsDataSource {
  final ApiClient _client;
  NewsDataSourceImpl(this._client);

  @override
  Future<List<NewsItemModel>> fetchTop({int limit = 10}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.newsTop,
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
}
