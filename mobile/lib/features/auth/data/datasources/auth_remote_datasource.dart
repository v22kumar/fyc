import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/token_model.dart';
import '../models/user_model.dart';
import '../../domain/entities/otp_challenge.dart';

abstract class AuthRemoteDataSource {
  Future<OtpChallenge> sendOtp({
    required String organizationId,
    required String phoneNumber,
  });

  Future<GoogleAuthResult> signInWithGoogle({required String organizationId});

  Future<void> signOutGoogle();

  /// Tell the server to revoke this account's refresh tokens (logout
  /// everywhere). Best-effort — a network failure must not block local logout.
  Future<void> serverLogout();

  Future<OtpVerifyResult> verifyOtp({
    required String verificationId,
    required String otpCode,
  });

  Future<TokenModel> registerUser({
    required String organizationId,
    required String phoneNumber,
    required String registrationToken,
    String? email,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
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
  Future<void> registerFcmToken(String token);
  Future<void> updateMyProfile(Map<String, dynamic> body);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _client;

  AuthRemoteDataSourceImpl(this._client);

  @override
  Future<OtpChallenge> sendOtp({
    required String organizationId,
    required String phoneNumber,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.otpSend,
        data: {'organization_id': organizationId, 'phone_number': phoneNumber},
      );
      // The server tries channels in order and reports which one carried the
      // code, so the member can be told where to look: "check WhatsApp" and
      // "check your messages" send them to different places.
      return OtpChallenge(
        id: response.data['verification_id'] as String,
        channel: response.data['channel'] as String?,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String verificationId,
    required String otpCode,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.otpVerify,
        data: {'verification_id': verificationId, 'otp_code': otpCode},
      );
      return OtpVerifyResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<TokenModel> registerUser({
    required String organizationId,
    required String phoneNumber,
    required String registrationToken,
    String? email,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
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
          'registration_token': registrationToken,
          // Email is optional now — only send it when provided.
          if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
          // Only sent when known. Absent means "ask me later", which the
          // profile prompts do.
          if ((dateOfBirth ?? '').isNotEmpty) 'date_of_birth': dateOfBirth,
          if (gender != null && gender.isNotEmpty) 'gender': gender,
          if (bloodGroup != null) 'blood_group': bloodGroup,
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
  Future<GoogleAuthResult> signInWithGoogle({required String organizationId}) async {
    // serverClientId MUST be this Firebase project's *Web* OAuth client, or
    // Google returns a null idToken ("couldn't get id token"). See
    // ApiConstants.googleServerClientId for the value and rationale.
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: ApiConstants.googleServerClientId,
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
      if (idToken == null) {
        // Google accepted the account and refused to vouch for it. That means
        // it does not recognise this build: it matches on the PAIR (package
        // name, signing certificate), and ours was registered against the
        // project's original package name rather than the one it ships as.
        //
        // "Not configured yet" was the wrong word for it — nothing is missing,
        // something is mismatched, and only somebody with the Firebase console
        // can put it right. tool/check_google_signin.py now catches this at
        // build time; this is what a member sees if one slips through.
        throw const AuthFailure(
            "Google sign-in isn't available on this build — "
            "please use your phone number");
      }

      final response = await _client.dio.post(
        ApiConstants.googleSignIn,
        data: {'organization_id': organizationId, 'id_token': idToken},
      );
      return GoogleAuthResult.fromJson(response.data as Map<String, dynamic>);
    } on AuthFailure {
      rethrow;
    } on DioException catch (e) {
      throw mapDioException(e);
    } on PlatformException catch (e) {
      if (e.code == 'network_error') {
        throw const AuthFailure(
            'Network error. Please check your connection and try again.');
      }
      // sign_in_failed with a "10" (DEVELOPER_ERROR) is Google saying this
      // package-and-certificate pair is not registered in the project. Same
      // cause as the null idToken above, arriving as an exception instead.
      throw const AuthFailure(
          "Google sign-in isn't available on this build — "
          "please use your phone number");
    } catch (e) {
      throw const ServerFailure();
    }
  }

  @override
  Future<void> signOutGoogle() async {
    try {
      await GoogleSignIn(scopes: ['email', 'profile']).signOut();
    } catch (_) {/* best-effort */}
  }

  @override
  Future<void> serverLogout() async {
    try {
      await _client.dio.post(ApiConstants.authLogout);
    } catch (_) {/* best-effort: local logout proceeds regardless */}
  }

  @override
  Future<void> registerFcmToken(String token) =>
      _client.dio.post(ApiConstants.fcmToken, data: {'token': token});

  @override
  Future<void> updateMyProfile(Map<String, dynamic> body) =>
      _client.dio.patch(ApiConstants.myProfile, data: body);
}
