import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/feed_item_model.dart';

abstract class CommunityFeedDataSource {
  Future<List<CommunityFeedItemModel>> fetchFeed();
}

class CommunityFeedDataSourceImpl implements CommunityFeedDataSource {
  final ApiClient _client;
  CommunityFeedDataSourceImpl(this._client);

  @override
  Future<List<CommunityFeedItemModel>> fetchFeed() async {
    try {
      final response = await _client.dio.get('${ApiConstants.community}/feed');
      final list = response.data as List<dynamic>;
      return list.map((e) => CommunityFeedItemModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
