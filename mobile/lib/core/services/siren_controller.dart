import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The alarm, and nothing that can accidentally stop it.
///
/// The version this replaces lived inside a bottom sheet and was stopped by
/// that sheet's `dispose()`. Dismiss the sheet — or have the phone taken from
/// you — and the siren went quiet. An alarm whose lifetime is a widget is not
/// an alarm.
///
/// So this is a process-level singleton with exactly two ways to stop: an
/// explicit tap, or the incident being stood down. It also posts an ongoing
/// notification carrying a **Stop** action, which is both the escape hatch for
/// a false alarm and the thing that keeps Android from treating the audio as
/// idle background noise while the app is not on screen.
class SirenController {
  SirenController._();

  static final SirenController instance = SirenController._();

  /// Anything that wants to show "Alarm: ON" listens here. The state lives in
  /// one place, so two screens can never disagree about whether it is running.
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);

  static const _notificationId = 91112;
  static const _channelId = 'fyc_alarm';
  static const stopActionId = 'stop_siren';

  AudioPlayer? _player;
  Timer? _haptics;
  Timer? _fallbackBeep;

  /// Start the siren. Idempotent, and never throws.
  ///
  /// [silent] is the member's own setting: some people need to raise an alarm
  /// without announcing it to the person they are raising it about. The haptic
  /// pulse still runs, because a phone buzzing in a pocket is feedback that the
  /// press registered and costs nothing.
  Future<void> start({bool silent = false}) async {
    if (isPlaying.value) return;
    isPlaying.value = true;

    _haptics?.cancel();
    _haptics = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!isPlaying.value) return;
      HapticFeedback.heavyImpact();
    });

    unawaited(_showOngoing());

    if (silent) return;

    try {
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      try {
        // ALARM usage on Android so it sounds through a silenced ringer, and
        // `stayAwake` so the CPU is not allowed to doze mid-alarm.
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
        // A plugin API mismatch must not stop playback entirely.
      }
      await player.setVolume(1.0);
      await player.play(AssetSource('audio/sos_siren.wav'), volume: 1.0);
    } catch (_) {
      _startFallbackBeep();
    }
  }

  Future<void> stop() async {
    if (!isPlaying.value) return;
    isPlaying.value = false;
    _haptics?.cancel();
    _haptics = null;
    _fallbackBeep?.cancel();
    _fallbackBeep = null;
    try {
      await _player?.stop();
    } catch (_) {}
    try {
      await FlutterLocalNotificationsPlugin().cancel(_notificationId);
    } catch (_) {}
  }

  void _startFallbackBeep() {
    // Audio unavailable — the system alert tone on a loop, so the alarm is
    // never completely silent when it was asked to be loud.
    _fallbackBeep?.cancel();
    _fallbackBeep = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!isPlaying.value) {
        t.cancel();
        return;
      }
      SystemSound.play(SystemSoundType.alert).catchError((_) {});
    });
  }

  /// An ongoing, undismissable notification with a Stop button.
  ///
  /// Ongoing rather than dismissable on purpose: swiping an alarm away by
  /// accident is exactly the failure this class exists to prevent. Stopping it
  /// takes a deliberate tap on a button that says Stop.
  Future<void> _showOngoing() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Emergency alarm',
            description: 'Shown while the SOS alarm is sounding',
            importance: Importance.max,
            playSound: false,
          ));

      await plugin.show(
        _notificationId,
        'SOS alarm is sounding',
        'Tap Stop to silence it.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Emergency alarm',
            importance: Importance.max,
            priority: Priority.max,
            ongoing: true,
            autoCancel: false,
            playSound: false,
            category: AndroidNotificationCategory.alarm,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(stopActionId, 'Stop',
                  showsUserInterface: false, cancelNotification: true),
            ],
          ),
        ),
        payload: 'siren',
      );
    } catch (_) {
      // No notification is a smaller problem than no alarm. Carry on.
    }
  }
}
