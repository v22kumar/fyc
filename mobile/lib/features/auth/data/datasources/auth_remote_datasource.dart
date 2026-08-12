import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/app_identity.dart';
import '../../../../core/services/error_reporter.dart';
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

  /// The number Google Play services actually reported, if it named one.
  ///
  /// It arrives buried in a message like "PlatformException(sign_in_failed,
  /// com.google.android.gms.common.api.ApiException: 10: , null, null)" — and
  /// that 10 is the entire diagnosis.
  static String _googleErrorCode(PlatformException e) {
    final match = RegExp(r'ApiException:\s*(\d+)').firstMatch(e.message ?? '');
    if (match != null) return 'code ${match.group(1)}';
    return e.code;
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
        // "no-token" rather than a bare failure: Google accepted the
        // account and declined to vouch for it, which is a different fault
        // from the sign-in call throwing, and they are fixed in different
        // places. Without the distinction both arrive as one sentence and the
        // next person guesses.
        ErrorReporter.instance.report(
            'google sign-in: account returned, idToken null '
            '(serverClientId=${ApiConstants.googleServerClientId.split("-").first})',
            null,
            context: 'auth/google');
        final viaBrowser = await _signInWithGoogleInBrowser(organizationId);
        if (viaBrowser != null) return viaBrowser;
        throw const AuthFailure(
            "Google sign-in isn't available on this build (no-token) — "
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
      // Google's own code is the diagnosis, and throwing it away is why this
      // took three wrong guesses. 10 is DEVELOPER_ERROR — the package and
      // certificate pair is not registered. 7 is a network fault. 12501 is the
      // member closing the sheet. They are three unrelated problems that were
      // all reported as "isn't configured".
      //
      // The code rides along in the message so somebody holding the phone can
      // read it out, and the full exception goes to the error reporter the
      // club's admins can already see.
      final code = _googleErrorCode(e);

      // Code 10 is Google saying it does not recognise this build. Every
      // static check said it should — so the remaining question is whether
      // the phone is presenting the certificate we believe it is. Ask the
      // phone, and put the answer where somebody can read it out.
      final sha1 = await AppIdentity.signingSha1();
      final package = await AppIdentity.packageName();
      ErrorReporter.instance.report(
          'google sign-in failed: code=${e.code} message=${e.message} '
          'package=$package sha1=$sha1',
          null,
          context: 'auth/google');
      // Before telling a member their build is the problem, try the road that
      // does not involve the build. Ordinary web OAuth in the browser has no
      // certificate in it, so it works on exactly the copies this failure is
      // about — and the member gets what they asked for instead of an excuse.
      final viaBrowser = await _signInWithGoogleInBrowser(organizationId);
      if (viaBrowser != null) return viaBrowser;

      throw AuthFailure(
          "Google sign-in isn't available on this build ($code)"
          "${sha1 != null ? "\nThis build: $package\n$sha1" : ""}"
          "\nPlease use your phone number.");
    } catch (e, stack) {
      // Every other failure in this method reports. An unexpected fault in the
      // browser fallback was the one that left no trace at all.
      ErrorReporter.instance.report(e, stack, context: 'auth/google');
      throw const ServerFailure();
    }
  }

  // ── The road that does not care how this build was signed ────────────────
  //
  // The native plugin shows Google the pair (package name, signing
  // certificate). Play re-signs uploaded bundles with its own key, so the Play
  // copy and the sideloaded copy present *different* certificates and either
  // can be missing from the Firebase console while the other is fine. When one
  // is missing Google answers DEVELOPER_ERROR — code 10 — and no amount of app
  // code can fix a fingerprint that lives in a console.
  //
  // This is ordinary web OAuth in the phone's browser, against the web client
  // id. There is no certificate anywhere in it, so it works on every copy.
  // Rather than register a custom URL scheme — one more per-build thing that
  // can be wrong, which is exactly what we are escaping — the app holds a
  // secret handle and asks the server whether the browser has finished.

  /// Opens a URL in the phone's browser. Replaced in tests, which have none.
  static Future<bool> Function(String url) openInBrowser = launchExternally;

  static Future<bool> launchExternally(String url) => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

  /// How long to keep asking. Long enough to find a Google password on a slow
  /// phone; short enough that an abandoned attempt stops eventually.
  static Duration browserSignInTimeout = const Duration(minutes: 3);

  /// The wait between polls. Replaced in tests so they do not sleep.
  static Future<void> Function(Duration d) pollDelay = Future.delayed;

  /// Returns the finished sign-in, or null if this road is not open — in which
  /// case the caller falls back to telling the member what went wrong.
  Future<GoogleAuthResult?> _signInWithGoogleInBrowser(
      String organizationId) async {
    final String sessionId;
    final String url;
    try {
      final start = await _client.dio.post(
        ApiConstants.googleBrowserStart,
        data: {'organization_id': organizationId},
      );
      final data = start.data as Map<String, dynamic>;
      sessionId = data['session_id'] as String;
      url = data['authorization_url'] as String;
    } on DioException {
      // 503 = the server has no web client secret, so this road was never
      // open. Not an error to show; just fall back to the native diagnosis.
      return null;
    } catch (_) {
      return null;
    }

    try {
      if (!await openInBrowser(url)) return null;
    } catch (_) {
      return null;
    }

    final deadline = DateTime.now().add(browserSignInTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await pollDelay(const Duration(seconds: 2));
      final Map<String, dynamic> body;
      try {
        final r = await _client.dio.get(
          ApiConstants.googleBrowserResult,
          queryParameters: {'session_id': sessionId},
        );
        body = r.data as Map<String, dynamic>;
      } on DioException {
        // A dropped poll is not a failed sign-in — the member may be on the
        // Google page with the phone's data flapping. Keep asking.
        continue;
      }

      switch (body['status'] as String?) {
        case 'ready':
          final result = body['result'];
          if (result is Map<String, dynamic>) {
            return GoogleAuthResult.fromJson(result);
          }
          return null;
        case 'failed':
          // Google itself refused, or the member cancelled. That sentence is
          // more useful than "this build isn't recognised", so it wins.
          throw AuthFailure(
              (body['error'] as String?) ?? 'Google sign-in did not complete.');
        case 'expired':
          return null;
      }
    }
    return null;
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
