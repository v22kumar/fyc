import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/constants/api_constants.dart';
import 'package:fyc_connect/core/network/api_client.dart';
import 'package:fyc_connect/features/auth/data/datasources/firebase_pnv_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebasePnvService pnvService;
  late MockApiClient mockApiClient;
  late MockDio mockDio;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.dio).thenReturn(mockDio);

    pnvService = FirebasePnvService(mockApiClient);

    // Mock MethodChannel 'fyc/firebase_pnv'
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('fyc/firebase_pnv'), (MethodCall methodCall) async {
      if (methodCall.method == 'getVerifiedPhoneNumber') {
        final args = methodCall.arguments is Map ? methodCall.arguments as Map : null;
        final isTestMode = args?['isTestMode'] as bool? ?? false;
        if (isTestMode) {
          return {'phoneNumber': '+919876543210', 'status': 'success'};
        }
        return {'phoneNumber': '+919487984964', 'status': 'success'};
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('fyc/firebase_pnv'), null);
  });

  test('requestVerifiedPhoneNumber returns phone number in test mode', () async {
    final phone = await pnvService.requestVerifiedPhoneNumber(
      isTestMode: true,
      testToken: FirebasePnvService.defaultTestToken,
    );

    expect(phone, equals('+919876543210'));
  });

  test('submitFirebaseVerification posts token to backend endpoint', () async {
    when(() => mockDio.post(
          ApiConstants.firebaseVerifyPhone,
          data: any(named: 'data'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: ApiConstants.firebaseVerifyPhone),
          data: {
            'claimed': true,
            'phone_number': '+919876543210',
            'phone_verified': true,
          },
          statusCode: 200,
        ));

    final result = await pnvService.submitFirebaseVerification(idToken: 'valid-test-token');

    expect(result, isNotNull);
    expect(result!['claimed'], isTrue);
    expect(result['phone_verified'], isTrue);
    expect(result['phone_number'], equals('+919876543210'));
  });
}
