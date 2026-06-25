import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required String id,
    required String titleEn,
    required String titleTa,
    required String bodyEn,
    required String bodyTa,
    required String notificationType,
    required bool isRead,
    required DateTime createdAt,
    Map<String, dynamic>? data,
  }) : super(
          id: id,
          titleEn: titleEn,
          titleTa: titleTa,
          bodyEn: bodyEn,
          bodyTa: bodyTa,
          notificationType: notificationType,
          isRead: isRead,
          createdAt: createdAt,
          data: data,
        );

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      titleEn: json['title_en'],
      titleTa: json['title_ta'],
      bodyEn: json['body_en'],
      bodyTa: json['body_ta'],
      notificationType: json['notification_type'],
      isRead: json['is_read'],
      createdAt: DateTime.parse(json['created_at']),
      data: json['data'],
    );
  }
}

class NotificationPreferenceModel extends NotificationPreferenceEntity {
  const NotificationPreferenceModel({
    required bool pushEnabled,
    required bool whatsappEnabled,
    required bool smsEnabled,
    required bool emailEnabled,
    required bool newsEnabled,
    required bool sportsEnabled,
    required bool communityEnabled,
    required bool eventsEnabled,
  }) : super(
          pushEnabled: pushEnabled,
          whatsappEnabled: whatsappEnabled,
          smsEnabled: smsEnabled,
          emailEnabled: emailEnabled,
          newsEnabled: newsEnabled,
          sportsEnabled: sportsEnabled,
          communityEnabled: communityEnabled,
          eventsEnabled: eventsEnabled,
        );

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceModel(
      pushEnabled: json['push_enabled'] ?? true,
      whatsappEnabled: json['whatsapp_enabled'] ?? true,
      smsEnabled: json['sms_enabled'] ?? false,
      emailEnabled: json['email_enabled'] ?? true,
      newsEnabled: json['news_enabled'] ?? true,
      sportsEnabled: json['sports_enabled'] ?? true,
      communityEnabled: json['community_enabled'] ?? true,
      eventsEnabled: json['events_enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_enabled': pushEnabled,
      'whatsapp_enabled': whatsappEnabled,
      'sms_enabled': smsEnabled,
      'email_enabled': emailEnabled,
      'news_enabled': newsEnabled,
      'sports_enabled': sportsEnabled,
      'community_enabled': communityEnabled,
      'events_enabled': eventsEnabled,
    };
  }
}
