import 'package:dio/dio.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/membership_model.dart';

abstract class MembershipDataSource {
  Future<MembershipModel> getMyCard();
}

class MembershipDataSourceImpl implements MembershipDataSource {
  final ApiClient _client;
  MembershipDataSourceImpl(this._client);

  @override
  Future<MembershipModel> getMyCard() async {
    try {
      final response = await _client.dio.get('/api/v1/membership/my-card');
      return MembershipModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const NotFoundFailure('No membership card found. Contact your administrator.');
      }
      throw mapDioException(e);
    }
  }
}
