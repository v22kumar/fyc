import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> myJourney() async =>
      ((await _api.dio.get('/api/v1/users/me/journey')).data as Map)
          .cast<String, dynamic>();

  @override
  Future<Map<String, dynamic>?> promptCatalogue() async {
    final data = (await _api.dio
            .get<dynamic>('${ApiConstants.baseUrl}/api/v1/profile-prompts/catalogue'))
        .data;
    return data is Map<String, dynamic> ? data : null;
  }

  @override
  Future<void> submitPromptAnswer(String path, Map<String, dynamic> body) =>
      _api.dio.post<void>('${ApiConstants.baseUrl}/api/v1/profile-prompts/$path',
          data: body);
}
