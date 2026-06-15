import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/failures.dart';
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
      final response = await _client.dio.get(ApiConstants.community);
      final list = response.data as List<dynamic>;
      return list
          .map((e) => CommunityProfileModel.fromJson(e as Map<String, dynamic>))
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
