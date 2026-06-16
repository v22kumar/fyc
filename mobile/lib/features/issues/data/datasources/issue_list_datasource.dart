import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/issue_detail_model.dart';

abstract class IssueListDataSource {
  Future<List<IssueDetailModel>> fetchIssues({String? status, String? category});
  Future<IssueDetailModel> getIssue(String id);
}

class IssueListDataSourceImpl implements IssueListDataSource {
  final ApiClient _client;
  IssueListDataSourceImpl(this._client);

  @override
  Future<List<IssueDetailModel>> fetchIssues({
    String? status,
    String? category,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (status != null) query['issue_status'] = status;
      if (category != null) query['category'] = category;
      final response = await _client.dio.get(
        ApiConstants.issues,
        queryParameters: query.isEmpty ? null : query,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => IssueDetailModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<IssueDetailModel> getIssue(String id) async {
    try {
      final response = await _client.dio.get('${ApiConstants.issues}/$id');
      return IssueDetailModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
