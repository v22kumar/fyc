import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../network/api_client.dart';
import '../../service_locator.dart';

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

  // ── Loud Siren / Silent Mode ────────────────────────────────────────────────
  static const _sirenKey = 'sos_loud_siren';

  static Future<bool> getLoudSiren() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sirenKey) ?? true;
  }

  static Future<void> setLoudSiren(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sirenKey, on);
  }

  // ── Shake to trigger ─────────────────────────────────────────────────────
  static const _shakeKey = 'sos_shake_to_trigger';

  static Future<bool> getShakeToTrigger() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shakeKey) ?? true;
  }

  static Future<void> setShakeToTrigger(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shakeKey, on);
  }

  // ── Loud siren ──────────────────────────────────────────────────────────────
  // A real, continuously-looping alarm — NOT a couple of quiet system beeps.
  // Plays a bundled two-tone siren asset through the device ALARM channel at
  // full volume (so it's loud even when media/ring volume is low), layered with
  // a heavy-haptic pulse. It keeps blaring until stopSiren() is called, which is
  // what an emergency alarm needs (attract attention / deter a threat).
  static AudioPlayer? _sirenPlayer;
  static Timer? _hapticTimer;
  static bool _sirenOn = false;

  static bool get isSirenPlaying => _sirenOn;

  /// Start the looping siren + haptic pulses. Idempotent. No-op in Silent mode.
  /// Falls back to the built-in system alert tone if the audio player can't
  /// start (e.g. widget tests / unsupported build), so there is always *some*
  /// audible signal.
  static Future<void> startSiren() async {
    if (_sirenOn) return;
    if (!await getLoudSiren()) return;
    _sirenOn = true;

    // Heavy-haptic pulse train — fires regardless of whether audio starts.
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!_sirenOn) return;
      HapticFeedback.heavyImpact();
    });

    try {
      final player = _sirenPlayer ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      // Route through the ALARM usage on Android so it plays loudly even on a
      // muted ringer; playback category on iOS so it sounds with the app active.
      try {
        await player.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ));
      } catch (_) {
        // Older/newer plugin API mismatch must not stop playback entirely.
      }
      await player.setVolume(1.0);
      await player.play(AssetSource('audio/sos_siren.wav'), volume: 1.0);
    } catch (_) {
      // Audio unavailable — degrade to the system alert tone loop so the alarm
      // is never completely silent.
      _fallbackBeep();
    }
  }

  /// Stop the siren + haptics.
  static Future<void> stopSiren() async {
    _sirenOn = false;
    _hapticTimer?.cancel();
    _hapticTimer = null;
    try {
      await _sirenPlayer?.stop();
    } catch (_) {}
  }

  static void _fallbackBeep() {
    // Keep beeping via the system alert tone while the siren is "on".
    Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!_sirenOn) {
        t.cancel();
        return;
      }
      SystemSound.play(SystemSoundType.alert).catchError((_) {});
    });
  }

  /// Broadcast an SOS to fellow FYC members in the org (Notify Nearby Members).
  /// Best-effort; returns false on any failure.
  static Future<bool> alertMembers({Position? pos}) async {
    try {
      await sl<ApiClient>().dio.post('/api/v1/notifications/sos-alert', data: {
        if (pos != null) 'latitude': pos.latitude,
        if (pos != null) 'longitude': pos.longitude,
      });
      return true;
    } catch (_) {
      return false;
    }
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
