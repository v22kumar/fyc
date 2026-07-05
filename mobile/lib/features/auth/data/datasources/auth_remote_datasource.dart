import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/token_model.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<String> sendOtp({
    required String organizationId,
    required String phoneNumber,
  });

  Future<TokenModel> signInWithGoogle({required String organizationId});

  Future<void> signOutGoogle();

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
      throw mapDioException(e);
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
      throw mapDioException(e);
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
      throw mapDioException(e);
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
      throw mapDioException(e);
    }
  }

  @override
  Future<UserModel> getMe() async {
    try {
      final response = await _client.dio.get(ApiConstants.me);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<TokenModel> signInWithGoogle({required String organizationId}) async {
    // serverClientId MUST be the *Web* OAuth client ID (client_type 3) of this
    // Firebase project — passing the Android client, or leaving it unset, makes
    // Google return a null idToken and login fails with "couldn't get id token".
    //
    // This value is NOT a secret: it already ships in google-services.json and
    // inside every APK, so we hardcode the project's Web client as the default
    // rather than depending on a GOOGLE_SERVER_CLIENT_ID build secret that can
    // be empty or misconfigured. A build may still override it via
    // --dart-define=GOOGLE_SERVER_CLIENT_ID=... for a different environment.
    const _webClientId =
        '986299606001-jj9nkt5grit2ra01dsf8gcqbt9k50lar.apps.googleusercontent.com';
    const _override = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: _override.isNotEmpty ? _override : _webClientId,
    );
    try {
      // Clear any cached Google session first so the account chooser always
      // appears — otherwise the previously signed-in account is silently
      // reused and users can't switch accounts after logging out.
      try {
        await googleSignIn.signOut();
      } catch (_) {/* no cached session — fine */}

      final account = await googleSignIn.signIn();
      if (account == null) throw const AuthFailure('Google sign-in cancelled');

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) throw const AuthFailure("Google login isn't configured yet — use your phone number");

      final response = await _client.dio.post(
        ApiConstants.googleSignIn,
        data: {'organization_id': organizationId, 'id_token': idToken},
      );
      return TokenModel.fromJson(response.data as Map<String, dynamic>);
    } on AuthFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapDioException(e);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed') {
        if (e.message != null && e.message!.contains('10')) {
          throw const AuthFailure("Google login isn't configured yet — use your phone number");
        } else if (e.code == 'network_error') {
          throw const AuthFailure('Network error. Please check your connection and try again.');
        }
      }
      throw AuthFailure("Google login isn't configured yet — use your phone number");
    } catch (e) {
      throw ServerFailure();
    }
  }

  @override
  Future<void> signOutGoogle() async {
    try {
      await GoogleSignIn(scopes: ['email', 'profile']).signOut();
    } catch (_) {/* best-effort */}
  }
}
