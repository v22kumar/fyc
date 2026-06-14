import 'package:dio/dio.dart';
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
      throw _map(e);
    }
  }

  Failure _map(DioException e) {
    if (e.type == DioExceptionType.connectionError) return const NetworkFailure();
    final detail = (e.response?.data as Map?)?['detail'] as String? ?? 'Error';
    if (e.response?.statusCode == 401) return AuthFailure(detail);
    if (e.response?.statusCode == 404) return ServerFailure('No membership card found. Contact your administrator.');
    return ServerFailure(detail);
  }
}
