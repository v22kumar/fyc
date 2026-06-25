import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/journey_model.dart';

abstract class JourneyDataSource {
  Future<JourneyModel> fetchJourney();
}

class JourneyDataSourceImpl implements JourneyDataSource {
  final ApiClient _client;
  JourneyDataSourceImpl(this._client);

  @override
  Future<JourneyModel> fetchJourney() async {
    try {
      final response = await _client.dio.get('/api/v1/users/me/journey');
      return JourneyModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
