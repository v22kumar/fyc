import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'siren_controller.dart';

/// Shows system-tray notifications while the app is in the FOREGROUND.
///
/// FCM auto-posts to the tray only when the app is backgrounded/killed; in the
/// foreground the OS hands the message to the app, so we re-post it ourselves
/// via a local notification. The channel id ("fyc_default") matches the
/// AndroidNotification.channel_id the backend sends, so background and
/// foreground notifications share one channel (sound/importance) and one tap
/// route.
class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'fyc_default',
    'General',
    description: 'Announcements, events and updates from FYC Connect',
    importance: Importance.high,
  );

  /// The channel an SOS arrives on, and the reason the alarm moved here.
  ///
  /// The siren used to sound on the phone of the person *raising* the SOS.
  /// That is the wrong phone: in a threat it announces to the person you are
  /// afraid of that you have called for help, and it drowns out the 112 call
  /// you are trying to make. The phone that has to be impossible to ignore is
  /// the one belonging to somebody who can come — a responder asleep at two in
  /// the morning, or your wife with her ringer off.
  ///
  /// So this channel plays the siren as its **notification sound**, at
  /// [AudioAttributesUsage.alarm], which sounds through a silenced ringer the
  /// way an alarm clock does. A channel's sound is fixed at creation by
  /// Android, which is exactly why it needs to be its own channel rather than
  /// a louder variant of the general one.
  static const sosChannelId = 'fyc_sos';

  static const AndroidNotificationChannel _sosChannel =
      AndroidNotificationChannel(
    sosChannelId,
    'Emergency (SOS)',
    description: 'Someone near you needs help. Rings like an alarm.',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('sos_siren'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
    enableLights: true,
  );

  /// Called from onSelectNotification with the tapped message's route payload.
  static void Function(String route)? onTapRoute;

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        // The alarm's Stop button. Handled here rather than on a screen
        // because the whole point of the siren rewrite is that it outlives
        // every screen — there may be nothing mounted to hear this.
        if (resp.actionId == SirenController.stopActionId) {
          SirenController.instance.stop();
          return;
        }
        final route = resp.payload;
        if (route != null && route.isNotEmpty && route != 'siren') {
          onTapRoute?.call(route);
        }
      },
    );
    // Create the channel up-front so the first notification shows immediately.
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.createNotificationChannel(_sosChannel);
  }

  /// Is this an SOS? Then it gets the alarm channel and the alarm treatment.
  static bool isSos(RemoteMessage message) =>
      message.data['type'] == 'SOS';

  /// Post a foreground FCM message to the system tray.
  static Future<void> showFromMessage(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final sos = isSos(message);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        sos ? _sosChannel.id : _channel.id,
        sos ? _sosChannel.name : _channel.name,
        channelDescription:
            sos ? _sosChannel.description : _channel.description,
        importance: sos ? Importance.max : Importance.high,
        priority: sos ? Priority.max : Priority.high,
        icon: '@mipmap/ic_launcher',
        // An SOS is a call for help, not news. `category` is what lets Android
        // treat it as urgent under Do Not Disturb, and the full-screen intent
        // is what wakes a locked screen instead of adding a quiet row nobody
        // sees until morning.
        category: sos ? AndroidNotificationCategory.call : null,
        fullScreenIntent: sos,
        sound: sos
            ? const RawResourceAndroidNotificationSound('sos_siren')
            : null,
        audioAttributesUsage: sos
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        timeoutAfter: sos ? const Duration(minutes: 5).inMilliseconds : null,
      ),
    );
    try {
      await _plugin.show(
        n.hashCode,
        n.title,
        n.body,
        details,
        payload: message.data['route'] as String?,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('LocalNotifications.show failed: $e');
    }
  }
}
