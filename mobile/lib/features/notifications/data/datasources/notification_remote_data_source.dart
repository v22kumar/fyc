import 'package:dio/dio.dart';
import 'notification_model.dart';

class NotificationRemoteDataSource {
  final Dio dio;

  NotificationRemoteDataSource(this.dio);

  Future<List<NotificationModel>> getNotifications() async {
    final response = await dio.get('/notifications');
    return (response.data as List)
        .map((e) => NotificationModel.fromJson(e))
        .toList();
  }

  Future<NotificationModel> markAsRead(String id) async {
    final response = await dio.put('/notifications/$id/read');
    return NotificationModel.fromJson(response.data);
  }

  Future<void> markAllAsRead() async {
    await dio.put('/notifications/read-all');
  }

  Future<void> trackClick(String id) async {
    await dio.put('/notifications/$id/track-click');
  }

  Future<NotificationPreferenceModel> getPreferences() async {
    final response = await dio.get('/notifications/preferences');
    return NotificationPreferenceModel.fromJson(response.data);
  }

  Future<NotificationPreferenceModel> updatePreferences(NotificationPreferenceModel prefs) async {
    final response = await dio.put(
      '/notifications/preferences',
      data: prefs.toJson(),
    );
    return NotificationPreferenceModel.fromJson(response.data);
  }
}
