import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Device-side safety plumbing: preferences, and the rung of the degradation
/// ladder that runs when there is no network.
///
/// Everything that used to live here and is now elsewhere:
///
/// * **The siren** moved to [SirenController] — it was stopped by the bottom
///   sheet's `dispose()`, so dismissing the screen silenced the alarm.
/// * **`alertMembers`** is gone with the endpoint it called, which broadcast to
///   every member of the organisation behind a button labelled "nearby".
/// * **Trusted contacts** moved to the server, so a phone that is taken or
///   smashed no longer takes the only copy with it. What stays here is a
///   read-only *cache* of them, for exactly one purpose: sending from the
///   handset when there is no network to raise an incident with.
/// A trusted contact as the device remembers them.
class CachedContact {
  const CachedContact({required this.name, required this.phone});
  final String name;
  final String phone;
}

class SosService {
  SosService._();

  /// India's single emergency number — police, fire and ambulance.
  static const emergencyNumber = '112';

  // ── Preferences ────────────────────────────────────────────────────────

  static const _sirenKey = 'sos_loud_siren';
  static const _shakeKey = 'sos_shake_to_trigger';
  static const _cacheKey = 'sos_cached_contacts';
  static const _pendingKey = 'sos_pending_incident';

  static Future<bool> getLoudSiren() async =>
      (await SharedPreferences.getInstance()).getBool(_sirenKey) ?? true;

  static Future<void> setLoudSiren(bool on) async =>
      (await SharedPreferences.getInstance()).setBool(_sirenKey, on);

  /// Live shake state, so toggling the setting starts and stops the detector
  /// without an app restart.
  ///
  /// **Off by default now.** It used to be on for everybody, and what it did
  /// was throw a modal over whatever they were doing — on a motorbike, in a
  /// pocket, every day, until the member turned the whole feature off. It is
  /// worth having only once the countdown exists to make a false trigger free.
  static final ValueNotifier<bool> shakeToTriggerListenable =
      ValueNotifier<bool>(false);

  static Future<bool> getShakeToTrigger() async {
    final on =
        (await SharedPreferences.getInstance()).getBool(_shakeKey) ?? false;
    shakeToTriggerListenable.value = on;
    return on;
  }

  static Future<void> setShakeToTrigger(bool on) async {
    await (await SharedPreferences.getInstance()).setBool(_shakeKey, on);
    shakeToTriggerListenable.value = on;
  }

  // ── The offline rung ───────────────────────────────────────────────────

  /// Keep a copy of the trusted contacts on the device.
  ///
  /// Written every time the server hands them over. It is never the source of
  /// truth — that moved to the server precisely so a lost phone cannot silence
  /// it — but a phone with no signal still has hands, and this is what those
  /// hands need.
  static Future<void> cacheContacts(List<CachedContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      json.encode([
        for (final c in contacts) {'name': c.name, 'phone': c.phone}
      ]),
    );
  }

  static Future<List<CachedContact>> cachedContacts() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [
        for (final row in json.decode(raw) as List)
          CachedContact(
            name: (row as Map)['name'] as String? ?? '',
            phone: row['phone'] as String? ?? '',
          )
      ].where((c) => c.phone.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  /// An SOS that could not reach the server, kept until it can.
  ///
  /// Stored rather than dropped because the alternative is a member who
  /// pressed the button, saw it fail, and has no record that they ever tried.
  static Future<void> queuePending(Map<String, dynamic> incident) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, json.encode(incident));
  }

  static Future<Map<String, dynamic>?> takePending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null || raw.isEmpty) return null;
    await prefs.remove(_pendingKey);
    try {
      return (json.decode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// The message a trusted contact gets when the device has to send it itself.
  ///
  /// Plain ASCII on purpose: a Tamil body is more thoughtful and also more
  /// likely to arrive mangled on an old handset, and this is the one message
  /// that absolutely must be readable when it lands.
  static String offlineMessage({
    String? name,
    double? latitude,
    double? longitude,
  }) {
    final who = (name != null && name.trim().isNotEmpty) ? name.trim() : 'A FYC member';
    final where = (latitude != null && longitude != null)
        ? ' Location: https://maps.google.com/?q=$latitude,$longitude'
        : ' (location unknown)';
    return 'SOS - $who needs help.$where - FYC Connect';
  }

  /// Hand the message to the SMS app, pre-filled.
  ///
  /// This is a *fallback*, and it is honest about what it is: the member still
  /// has to press send in another application. The screen says so rather than
  /// claiming the feature "works offline", which is what the four green ticks
  /// used to claim while nothing behind them did.
  static Future<bool> composeSms(List<String> numbers, String message) async {
    final cleaned =
        numbers.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
    if (cleaned.isEmpty) return false;
    // iOS does not reliably honour comma-separated recipients in an `sms:`
    // URL — it often opens only the first, or fails outright. Better to reach
    // one than none.
    final recipients = Platform.isIOS ? cleaned.first : cleaned.join(',');
    return _launch(Uri(
      scheme: 'sms',
      path: recipients,
      queryParameters: {'body': message},
    ));
  }

  /// Open the dialler on 112. Does not auto-dial.
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
