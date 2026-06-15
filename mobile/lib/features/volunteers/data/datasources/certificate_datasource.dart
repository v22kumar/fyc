import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';

abstract class CertificateDataSource {
  /// Fetches the volunteer certificate PDF as raw bytes (auth header
  /// auto-added by ApiClient). Ready for use once path_provider is added.
  Future<Uint8List> fetchCertificateBytes();
}

class CertificateDataSourceImpl implements CertificateDataSource {
  final ApiClient _client;
  CertificateDataSourceImpl(this._client);

  @override
  Future<Uint8List> fetchCertificateBytes() async {
    try {
      final response = await _client.dio.get<List<int>>(
        ApiConstants.myCertificate,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? <int>[]);
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
