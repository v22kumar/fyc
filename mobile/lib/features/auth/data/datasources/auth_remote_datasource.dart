import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/token_model.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<String> sendOtp({
    required String organizationId,
    required String phoneNumber,
  });

  Future<TokenModel> verifyOtp({
    required String verificationId,
    required String otpCode,
  });

  Future<TokenModel> registerUser({
    required String organizationId,
    required String phoneNumber,
    required String role,
    required String fullNameTa,
    required String fullNameEn,
    required String preferredLanguage,
  });

  Future<TokenModel> loginWithPassword({
    required String organizationId,
    required String username,
    required String password,
  });

  Future<UserModel> getMe();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _client;

  AuthRemoteDataSourceImpl(this._client);

  @override
  Future<String> sendOtp({
    required String organizationId,
    required String phoneNumber,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.otpSend,
        data: {'organization_id': organizationId, 'phone_number': phoneNumber},
      );
      return response.data['verification_id'] as String;
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<TokenModel> verifyOtp({
    required String verificationId,
    required String otpCode,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.otpVerify,
        data: {'verification_id': verificationId, 'otp_code': otpCode},
      );
      return TokenModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<TokenModel> registerUser({
    required String organizationId,
    required String phoneNumber,
    required String role,
    required String fullNameTa,
    required String fullNameEn,
    required String preferredLanguage,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.register,
        data: {
          'organization_id': organizationId,
          'phone_number': phoneNumber,
          'role': role,
          'full_name_ta': fullNameTa,
          'full_name_en': fullNameEn,
          'preferred_language': preferredLanguage,
        },
      );
      return TokenModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<TokenModel> loginWithPassword({
    required String organizationId,
    required String username,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.loginPassword,
        data: {
          'organization_id': organizationId,
          'username': username,
          'password': password,
        },
      );
      return TokenModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  @override
  Future<UserModel> getMe() async {
    try {
      final response = await _client.dio.get(ApiConstants.me);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Failure _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkFailure();
    }
    final statusCode = e.response?.statusCode;
    final detail = (e.response?.data as Map?)?['detail'] as String? ?? e.message ?? 'Unknown error';
    if (statusCode == 401 || statusCode == 403) {
      return AuthFailure(detail);
    }
    return ServerFailure(detail);
  }
}
