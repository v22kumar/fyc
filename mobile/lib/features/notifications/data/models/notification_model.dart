import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.titleEn,
    required super.titleTa,
    required super.bodyEn,
    required super.bodyTa,
    required super.notificationType,
    required super.isRead,
    required super.createdAt,
    super.data,
  });

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
    required super.pushEnabled,
    required super.whatsappEnabled,
    required super.smsEnabled,
    required super.emailEnabled,
    required super.newsEnabled,
    required super.sportsEnabled,
    required super.communityEnabled,
    required super.eventsEnabled,
  });

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
