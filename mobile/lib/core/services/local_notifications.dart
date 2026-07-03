import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  /// Called from onSelectNotification with the tapped message's route payload.
  static void Function(String route)? onTapRoute;

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final route = resp.payload;
        if (route != null && route.isNotEmpty) onTapRoute?.call(route);
      },
    );
    // Create the channel up-front so the first notification shows immediately.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// Post a foreground FCM message to the system tray.
  static Future<void> showFromMessage(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
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
