import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/core/network/api_client.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/features/auth/data/datasources/auth_remote_datasource.dart';

/// Google sign-in that survives Google not recognising the build.
///
/// The native plugin authenticates with the pair (package name, signing
/// certificate). Play re-signs uploaded bundles with its own key, so the Play
/// copy and the sideloaded copy present *different* certificates and either can
/// be missing from the Firebase console while the other is fine. When one is,
/// Google answers `DEVELOPER_ERROR` — code 10 — and days went into re-reading a
/// chain of static checks that all said it should have worked.
///
/// Nothing in the app can fix a fingerprint that lives in a console. So the app
/// stops trying: it falls back to ordinary web OAuth in the browser, which has
/// no certificate in it anywhere.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const googleChannel = MethodChannel('plugins.flutter.io/google_sign_in');

  /// A phone whose Google Play services refuses this build with code 10.
  void googleRefusesThisBuild() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(googleChannel, (call) async {
      if (call.method == 'init' || call.method == 'signOut') return null;
      throw PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 10: , '
            'null, null',
      );
    });
  }

  late List<String> requested;
  late List<String> opened;

  setUp(() {
    requested = [];
    opened = [];
    AuthRemoteDataSourceImpl.pollDelay = (_) async {};
    AuthRemoteDataSourceImpl.openInBrowser = (url) async {
      opened.add(url);
      return true;
    };
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(googleChannel, null);
    AuthRemoteDataSourceImpl.openInBrowser =
        AuthRemoteDataSourceImpl.launchExternally;
    AuthRemoteDataSourceImpl.pollDelay = Future.delayed;
  });

  /// A backend that answers the browser-flow endpoints from a script.
  Future<AuthRemoteDataSourceImpl> serverThatAnswers(
      Map<String, dynamic> Function(String path) answer,
      {int Function(String path)? statusFor}) async {
    SharedPreferences.setMockInitialValues({});
    final client = ApiClient(LocalStorage(await SharedPreferences.getInstance()));
    client.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requested.add(options.path);
        final code = statusFor?.call(options.path) ?? 200;
        if (code >= 400) {
          return handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: code),
            type: DioExceptionType.badResponse,
          ));
        }
        handler.resolve(Response(
          requestOptions: options,
          statusCode: code,
          data: answer(options.path),
        ));
      },
    ));
    return AuthRemoteDataSourceImpl(client);
  }

  test('code 10 opens the browser instead of dead-ending the member', () async {
    googleRefusesThisBuild();
    var polls = 0;
    final ds = await serverThatAnswers((path) {
      if (path.contains('browser/start')) {
        return {
          'session_id': 'sess-1',
          'authorization_url': 'https://accounts.google.com/o/oauth2/v2/auth?x=1',
          'expires_in': 600,
        };
      }
      // Two "still waiting" polls, because a member takes time in the browser.
      if (++polls < 3) return {'status': 'pending'};
      return {
        'status': 'ready',
        'result': {
          'access_token': 'at',
          'refresh_token': 'rt',
          'token_type': 'bearer',
          'user': {
            'id': 'u1',
            'phone_number': '+919888812345',
            'email': 'member@example.com',
            'role': 'MEMBER',
            'is_verified': true,
            'preferred_language': 'en',
          },
        },
      };
    });

    final result = await ds.signInWithGoogle(organizationId: 'org-1');

    expect(opened, hasLength(1),
        reason: 'the member asked to sign in with Google — give them Google, '
            'not an explanation of certificates');
    expect(result.token?.accessToken, 'at');
    expect(polls, 3, reason: 'it keeps asking while the member is still there');
  });

  test('a brand-new Google account still routes to registration', () async {
    googleRefusesThisBuild();
    final ds = await serverThatAnswers((path) {
      if (path.contains('browser/start')) {
        return {
          'session_id': 'sess-2',
          'authorization_url': 'https://accounts.google.com/x',
          'expires_in': 600,
        };
      }
      return {
        'status': 'ready',
        'result': {
          'needs_registration': true,
          'email': 'stranger@example.com',
          'full_name': 'A Stranger',
        },
      };
    });

    final result = await ds.signInWithGoogle(organizationId: 'org-1');

    expect(result.needsRegistration, isTrue);
    expect(result.email, 'stranger@example.com');
  });

  test("Google's own refusal is what the member reads, not ours", () async {
    googleRefusesThisBuild();
    final ds = await serverThatAnswers((path) {
      if (path.contains('browser/start')) {
        return {
          'session_id': 'sess-3',
          'authorization_url': 'https://accounts.google.com/x',
          'expires_in': 600,
        };
      }
      return {
        'status': 'failed',
        'error': 'Google refused the sign-in (redirect_uri_mismatch).',
      };
    });

    expect(
      () => ds.signInWithGoogle(organizationId: 'org-1'),
      throwsA(isA<AuthFailure>().having((f) => f.message, 'message',
          contains('redirect_uri_mismatch'))),
    );
  });

  test('with no browser road configured, the fingerprint diagnosis survives',
      () async {
    googleRefusesThisBuild();
    // 503 = the server has no web client secret. The fallback was never open,
    // so the member must still get the sentence that says what to fix.
    final ds = await serverThatAnswers((_) => {},
        statusFor: (path) => path.contains('browser/start') ? 503 : 200);

    await expectLater(
      ds.signInWithGoogle(organizationId: 'org-1'),
      throwsA(isA<AuthFailure>()
          .having((f) => f.message, 'message', contains('code 10'))),
    );
    expect(opened, isEmpty, reason: 'never open a browser we cannot finish in');
  });

  test('a dropped poll is not a failed sign-in', () async {
    googleRefusesThisBuild();
    var polls = 0;
    final ds = await serverThatAnswers(
      (path) {
        if (path.contains('browser/start')) {
          return {
            'session_id': 'sess-4',
            'authorization_url': 'https://accounts.google.com/x',
            'expires_in': 600,
          };
        }
        return {
          'status': 'ready',
          'result': {
            'access_token': 'at',
            'refresh_token': 'rt',
            'token_type': 'bearer',
            'user': {
              'id': 'u1',
              'phone_number': '+919888812345',
              'email': 'member@example.com',
              'role': 'MEMBER',
              'is_verified': true,
              'preferred_language': 'en',
            },
          },
        };
      },
      // The phone's data flaps while the member is on the Google page.
      statusFor: (path) =>
          path.contains('browser/result') && ++polls == 1 ? 502 : 200,
    );

    final result = await ds.signInWithGoogle(organizationId: 'org-1');
    expect(result.token?.accessToken, 'at');
  });
}
