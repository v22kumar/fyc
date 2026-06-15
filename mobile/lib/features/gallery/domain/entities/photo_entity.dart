import 'package:equatable/equatable.dart';
import '../../../../core/constants/api_constants.dart';

class PhotoEntity extends Equatable {
  final String id;
  final String eventId;
  final String? uploadedByUserId;
  final String photoUrl;
  final String? captionTa;
  final String? captionEn;
  final DateTime? takenAt;
  final String organizationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PhotoEntity({
    required this.id,
    required this.eventId,
    this.uploadedByUserId,
    required this.photoUrl,
    this.captionTa,
    this.captionEn,
    this.takenAt,
    required this.organizationId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Absolute image URL. [photoUrl] may be a relative path like
  /// '/uploads/xyz.jpg'; prefix with [ApiConstants.baseUrl] when it does not
  /// already start with 'http'.
  String get absoluteUrl =>
      photoUrl.startsWith('http') ? photoUrl : '${ApiConstants.baseUrl}$photoUrl';

  /// Bilingual caption, falling back to the other language then empty.
  String displayCaption(String lang) {
    final ta = captionTa ?? '';
    final en = captionEn ?? '';
    if (lang == 'ta') return ta.isNotEmpty ? ta : en;
    return en.isNotEmpty ? en : ta;
  }

  @override
  List<Object?> get props => [id, eventId, photoUrl, takenAt, createdAt];
}
