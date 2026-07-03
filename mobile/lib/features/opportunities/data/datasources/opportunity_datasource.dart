import 'package:dio/dio.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/opportunity_model.dart';

abstract class OpportunityDataSource {
  Future<List<OpportunityModel>> fetchOpportunities();
  Future<void> applyForOpportunity(String id);
  Future<OpportunityModel> createOpportunity(Map<String, dynamic> body);
}

class OpportunityDataSourceImpl implements OpportunityDataSource {
  final ApiClient _client;
  OpportunityDataSourceImpl(this._client);

  static const String _opportunities = '/api/v1/opportunities';

  @override
  Future<List<OpportunityModel>> fetchOpportunities() async {
    try {
      final response = await _client.dio.get(_opportunities);
      final list = response.data as List<dynamic>;
      return list
          .map((e) => OpportunityModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<void> applyForOpportunity(String id) async {
    try {
      await _client.dio.post('$_opportunities/$id/apply');
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<OpportunityModel> createOpportunity(Map<String, dynamic> body) async {
    try {
      final response = await _client.dio.post(_opportunities, data: body);
      return OpportunityModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
