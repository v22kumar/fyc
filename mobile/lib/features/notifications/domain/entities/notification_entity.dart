class NotificationEntity {
  final String id;
  final String titleEn;
  final String titleTa;
  final String bodyEn;
  final String bodyTa;
  final String notificationType;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const NotificationEntity({
    required this.id,
    required this.titleEn,
    required this.titleTa,
    required this.bodyEn,
    required this.bodyTa,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
    this.data,
  });
}

class NotificationPreferenceEntity {
  final bool pushEnabled;
  final bool whatsappEnabled;
  final bool smsEnabled;
  final bool emailEnabled;
  final bool newsEnabled;
  final bool sportsEnabled;
  final bool communityEnabled;
  final bool eventsEnabled;

  const NotificationPreferenceEntity({
    required this.pushEnabled,
    required this.whatsappEnabled,
    required this.smsEnabled,
    required this.emailEnabled,
    required this.newsEnabled,
    required this.sportsEnabled,
    required this.communityEnabled,
    required this.eventsEnabled,
  });
}
