import '../../domain/entities/feed_item_entity.dart';

class CommunityFeedItemModel extends CommunityFeedItemEntity {
  const CommunityFeedItemModel({
    required super.itemType,
    required super.id,
    super.titleEn,
    super.titleTa,
    super.subtitleEn,
    super.subtitleTa,
    super.imageUrl,
    required super.createdAt,
    super.metadata,
  });

  factory CommunityFeedItemModel.fromJson(Map<String, dynamic> json) {
    return CommunityFeedItemModel(
      itemType: json['item_type'] as String,
      id: json['id'] as String,
      titleEn: json['title_en'] as String?,
      titleTa: json['title_ta'] as String?,
      subtitleEn: json['subtitle_en'] as String?,
      subtitleTa: json['subtitle_ta'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_type': itemType,
      'id': id,
      'title_en': titleEn,
      'title_ta': titleTa,
      'subtitle_en': subtitleEn,
      'subtitle_ta': subtitleTa,
      'image_url': imageUrl,
      'created_at': createdAt,
      'metadata': metadata,
    };
  }
}
