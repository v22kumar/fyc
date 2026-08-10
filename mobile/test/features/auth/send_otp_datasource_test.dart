import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/network/api_client.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/features/auth/data/datasources/auth_remote_datasource.dart';

/// The handle the server gave us has to be the handle we send back.
///
/// It was not. `sendOtp` packed the id and the delivery channel into one
/// delimited string, and the line that built it read:
///
/// ```dart
/// return channel == null ? id : '\$id|\$channel';
/// ```
///
/// The `$` signs are escaped, so that is not interpolation — it is the literal
/// text `$id|$channel`. Every sign-in posted the handle `"$id"` to
/// `/auth/otp/verify`, the server had of course never stored anything under
/// that, and the member was told **"Invalid or expired verification ID"** the
/// instant they typed a correct code.
///
/// Nothing caught it. The SMS always arrived, because sending worked; only the
/// handle was rubbish. From a phone it looked like Twilio, or the new domain,
/// or an expiry, or a server restart — and every one of those was investigated
/// before anybody looked at this line. The whole auth stack was tested except
/// the one hop where the server's answer is read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AuthRemoteDataSourceImpl> _dsReturning(Map<String, dynamic> body) async {
    SharedPreferences.setMockInitialValues({});
    final client = ApiClient(LocalStorage(await SharedPreferences.getInstance()));
    client.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: body),
      ),
    ));
    return AuthRemoteDataSourceImpl(client);
  }

  test('the handle comes back exactly as the server sent it', () async {
    final ds = await _dsReturning({
      'message': 'OTP sent successfully',
      'verification_id': 'v_ab12cd34ef56',
      'channel': 'sms',
    });

    final challenge = await ds.sendOtp(
        organizationId: 'org-1', phoneNumber: '+919487984964');

    expect(challenge.id, 'v_ab12cd34ef56',
        reason: 'this is what /auth/otp/verify looks up — a wrong value here '
            'is a login that can never succeed');
    expect(challenge.channel, 'sms');
    // The specific corruption that shipped.
    expect(challenge.id, isNot(contains(r'$')));
    expect(challenge.id, isNot(contains('|')));
  });

  test('a server that names no channel still yields a usable handle', () async {
    final ds = await _dsReturning({
      'message': 'OTP sent successfully',
      'verification_id': 'v_99887766aabb',
      'channel': null,
    });

    final challenge = await ds.sendOtp(
        organizationId: 'org-1', phoneNumber: '+919487984964');

    expect(challenge.id, 'v_99887766aabb');
    expect(challenge.channel, isNull);
  });
}
