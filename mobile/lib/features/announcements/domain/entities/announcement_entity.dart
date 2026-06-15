import 'package:equatable/equatable.dart';

class AnnouncementEntity extends Equatable {
  final String id;
  final String titleTa;
  final String titleEn;
  final String bodyTa;
  final String bodyEn;
  final String category;
  final bool isPinned;
  final DateTime? expiresAt;
  final String? bannerUrl;
  final String? createdByUserId;
  final String? geographyId;
  final String organizationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AnnouncementEntity({
    required this.id,
    required this.titleTa,
    required this.titleEn,
    required this.bodyTa,
    required this.bodyEn,
    required this.category,
    required this.isPinned,
    this.expiresAt,
    this.bannerUrl,
    this.createdByUserId,
    this.geographyId,
    required this.organizationId,
    required this.createdAt,
    required this.updatedAt,
  });

  String displayTitle(String lang) => lang == 'ta' ? titleTa : titleEn;
  String displayBody(String lang) => lang == 'ta' ? bodyTa : bodyEn;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String get categoryEmoji {
    switch (category) {
      case 'BLOOD_REQUEST':
        return '🩸';
      case 'EVENT':
        return '🎉';
      case 'OPPORTUNITY':
        return '📚';
      case 'ALERT':
        return '⚠️';
      case 'GREEN_DRIVE':
        return '🌱';
      case 'GENERAL':
      default:
        return '📢';
    }
  }

  String categoryLabel(String lang) {
    switch (category) {
      case 'BLOOD_REQUEST':
        return lang == 'ta' ? 'இரத்த வேண்டுகோள்' : 'Blood Request';
      case 'EVENT':
        return lang == 'ta' ? 'நிகழ்வு' : 'Event';
      case 'OPPORTUNITY':
        return lang == 'ta' ? 'வாய்ப்பு' : 'Opportunity';
      case 'ALERT':
        return lang == 'ta' ? 'எச்சரிக்கை' : 'Alert';
      case 'GREEN_DRIVE':
        return lang == 'ta' ? 'பசுமை இயக்கம்' : 'Green Drive';
      case 'GENERAL':
      default:
        return lang == 'ta' ? 'பொது' : 'General';
    }
  }

  @override
  List<Object?> get props => [
        id,
        titleTa,
        titleEn,
        bodyTa,
        bodyEn,
        category,
        isPinned,
        expiresAt,
        bannerUrl,
        geographyId,
        organizationId,
        createdAt,
        updatedAt,
      ];
}
