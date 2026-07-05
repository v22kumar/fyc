import 'dart:convert';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// SOS emergency helper.
///
/// Everything here is best-effort and never throws to the caller — in a real
/// emergency a permission prompt or a missing GPS fix must not stop the user
/// from getting a message out, so location is optional and failures degrade
/// gracefully (send without a map link, still offer to dial).
class SosService {
  static const _contactsKey = 'sos_trusted_contacts';

  /// India's single emergency number (police/fire/ambulance).
  static const emergencyNumber = '112';

  static Future<List<String>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return List<String>.from(json.decode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveContacts(List<String> numbers) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = numbers
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    await prefs.setString(_contactsKey, json.encode(cleaned));
  }

  /// Best-effort current location. Returns null (never throws) if location is
  /// off, denied, or times out — the SOS still goes out without a map link.
  static Future<Position?> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static String buildMessage({String? name, Position? pos}) {
    final who = (name != null && name.trim().isNotEmpty) ? name.trim() : 'A FYC member';
    final buf = StringBuffer('🆘 SOS — $who needs help.');
    if (pos != null) {
      buf.write(
        ' Location: https://maps.google.com/?q=${pos.latitude},${pos.longitude}',
      );
    } else {
      buf.write(' (location unavailable)');
    }
    return buf.toString();
  }

  /// Open the SMS composer pre-filled with [message] to [numbers]. Returns
  /// false if there is nothing to send to or the composer can't be opened.
  static Future<bool> sendSms(List<String> numbers, String message) async {
    final cleaned =
        numbers.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
    if (cleaned.isEmpty) return false;
    // iOS doesn't reliably honour comma-separated recipients in an sms: URL
    // (it often opens only the first, or fails), so target just the primary
    // contact there — better to reach one than none in an emergency. Android
    // handles the comma-separated list fine.
    final recipients = Platform.isIOS ? cleaned.first : cleaned.join(',');
    final uri = Uri(
      scheme: 'sms',
      path: recipients,
      queryParameters: {'body': message},
    );
    return _launch(uri);
  }

  /// Open the dialer on the emergency number (does not auto-dial).
  static Future<bool> callEmergency() =>
      _launch(Uri(scheme: 'tel', path: emergencyNumber));

  static Future<bool> _launch(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }
}
