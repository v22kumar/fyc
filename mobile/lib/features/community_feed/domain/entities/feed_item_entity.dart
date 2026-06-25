import 'package:equatable/equatable.dart';

class CommunityFeedItemEntity extends Equatable {
  final String itemType;
  final String id;
  final String? titleEn;
  final String? titleTa;
  final String? subtitleEn;
  final String? subtitleTa;
  final String? imageUrl;
  final String createdAt;
  final Map<String, dynamic>? metadata;

  const CommunityFeedItemEntity({
    required this.itemType,
    required this.id,
    this.titleEn,
    this.titleTa,
    this.subtitleEn,
    this.subtitleTa,
    this.imageUrl,
    required this.createdAt,
    this.metadata,
  });

  String get displayTitleTa => titleTa?.isNotEmpty == true ? titleTa! : titleEn ?? '';
  String get displayTitleEn => titleEn?.isNotEmpty == true ? titleEn! : titleTa ?? '';
  
  String get displaySubtitleTa => subtitleTa?.isNotEmpty == true ? subtitleTa! : subtitleEn ?? '';
  String get displaySubtitleEn => subtitleEn?.isNotEmpty == true ? subtitleEn! : subtitleTa ?? '';

  @override
  List<Object?> get props => [
        itemType,
        id,
        titleEn,
        titleTa,
        subtitleEn,
        subtitleTa,
        imageUrl,
        createdAt,
        metadata,
      ];
}
