import 'package:dio/dio.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/contact_model.dart';

abstract class ContactDataSource {
  Future<List<ContactModel>> fetchContacts({String? category});
}

class ContactDataSourceImpl implements ContactDataSource {
  final ApiClient _client;
  ContactDataSourceImpl(this._client);

  @override
  Future<List<ContactModel>> fetchContacts({String? category}) async {
    try {
      final response = await _client.dio.get(
        '/api/v1/directory',
        queryParameters: category != null ? {'category': category} : null,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => ContactModel.fromJson(e as Map<String, dynamic>))
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
