import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

class AiDatasource {
  final ApiClient _apiClient;

  AiDatasource(this._apiClient);

  Future<Map<String, dynamic>> getDailyDigest() async {
    final response = await _apiClient.dio.get('/api/v1/ai/daily-digest');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getNewsSummary() async {
    final response = await _apiClient.dio.get('/api/v1/ai/news-summary');
    return response.data as Map<String, dynamic>;
  }
}
