import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/community_profile_model.dart';

abstract class CommunityDataSource {
  Future<List<CommunityProfileModel>> fetchProfiles();
}

class CommunityDataSourceImpl implements CommunityDataSource {
  final ApiClient _client;
  CommunityDataSourceImpl(this._client);

  @override
  Future<List<CommunityProfileModel>> fetchProfiles() async {
    try {
      // available_only defaults to true server-side, which hides registered
      // members who haven't marked themselves available — making the directory
      // look empty. Request all profiles; availability is shown per-card.
      final response = await _client.dio.get(
        ApiConstants.community,
        queryParameters: {'available_only': false},
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => CommunityProfileModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
