import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/thirukkural_model.dart';

abstract class ThirukkuralDataSource {
  Future<ThirukkuralModel> fetchDaily();
}

class ThirukkuralDataSourceImpl implements ThirukkuralDataSource {
  final ApiClient _client;
  ThirukkuralDataSourceImpl(this._client);

  @override
  Future<ThirukkuralModel> fetchDaily() async {
    try {
      final response = await _client.dio.get(ApiConstants.thirukkuralDaily);
      return ThirukkuralModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
