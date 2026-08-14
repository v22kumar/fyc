import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fyc_connect/core/network/api_client.dart';
import 'package:fyc_connect/core/constants/api_constants.dart';

/// Firebase Phone Number Verification (PNV) Service.
///
/// Communicates with native Android Firebase PNV library via MethodChannel
/// and links the verified phone number with the FYC Connect backend.
class FirebasePnvService {
  static const MethodChannel _channel = MethodChannel('fyc/firebase_pnv');

  final ApiClient _apiClient;

  // Active testing token from Firebase Console or environment override
  static const String defaultTestToken = String.fromEnvironment(
    'FIREBASE_PNV_TEST_TOKEN',
    defaultValue:
        'AVweKohajldemHxif0W11cIpdIm8RIbljpFaXD_Oc7vymmQHAZBjW01CWcxLuV9K0YbZ74MCDa58c84Dcq438WCsjWVu-RM_UWHY_i-YJ3ID1GbAvZ6onBkY_N8h-ZXdieHfZBGI4fbeM6gK6yoi0l8G0A',
  );

  FirebasePnvService(this._apiClient);

  /// Triggers native Firebase PNV verification on Android.
  ///
  /// Returns the verified E.164 phone number (e.g., "+919876543210") or null on cancellation/failure.
  Future<String?> requestVerifiedPhoneNumber({
    bool isTestMode = true,
    String testToken = defaultTestToken,
  }) async {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) {
      debugPrint('[FirebasePnv] PNV is only supported natively on Android currently.');
      return null;
    }

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getVerifiedPhoneNumber',
        {
          'isTestMode': isTestMode,
          'testToken': testToken,
        },
      );

      if (result == null) return null;
      final phone = result['phoneNumber'] as String?;
      return phone;
    } on PlatformException catch (e) {
      debugPrint('[FirebasePnv] PlatformException: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[FirebasePnv] Error: $e');
      return null;
    }
  }

  /// Verifies and attaches a Firebase verified phone token to the active user session.
  Future<Map<String, dynamic>?> submitFirebaseVerification({
    required String idToken,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.firebaseVerifyPhone,
        data: {'id_token': idToken},
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return null;
    } catch (e) {
      debugPrint('[FirebasePnv] Backend verification failed: $e');
      rethrow;
    }
  }
}
