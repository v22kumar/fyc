import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<dynamic>> notifications() async =>
      (await _api.dio.get('/api/v1/notifications')).data as List<dynamic>;

  @override
  Future<List<dynamic>> events() async =>
      (await _api.dio.get('/api/v1/events')).data as List<dynamic>;

  @override
  Future<List<dynamic>> communityFeed({int limit = 5}) async =>
      (await _api.dio.get('/api/v1/community/feed',
              queryParameters: {'limit': limit}))
          .data as List<dynamic>;

  @override
  Future<Map<String, dynamic>> communityStats() async =>
      ((await _api.dio.get('/api/v1/community/stats')).data as Map)
          .cast<String, dynamic>();

  @override
  Future<Map<String, dynamic>> liveScores() async =>
      ((await _api.dio.get('/api/v1/sports/live')).data as Map)
          .cast<String, dynamic>();

  @override
  Future<Map<String, dynamic>> weather(
          {required double lat, required double lon}) async =>
      ((await _api.dio.get(ApiConstants.weatherCurrent,
                  queryParameters: {'lat': lat, 'lon': lon}))
              .data as Map)
          .cast<String, dynamic>();

  @override
  Future<Map<String, dynamic>> goldPrice() async =>
      ((await _api.dio.get(ApiConstants.goldPrice)).data as Map)
          .cast<String, dynamic>();

  @override
  Future<List<dynamic>> celebrationsToday() async =>
      ((await _api.dio.get('/api/v1/users/celebrations/today')).data
          as List?) ??
      const [];
}
