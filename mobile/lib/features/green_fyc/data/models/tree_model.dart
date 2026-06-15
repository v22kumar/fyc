import '../../domain/entities/tree_entity.dart';

class TreeModel extends TreeEntity {
  const TreeModel({
    required super.id,
    required super.organizationId,
    super.driveId,
    super.registeredByUserId,
    super.speciesTa,
    super.speciesEn,
    super.latitude,
    super.longitude,
    super.geographyId,
    required super.plantedDate,
    super.photoUrl,
    super.growthPhotoUrl,
    required super.status,
    super.notes,
  });

  factory TreeModel.fromJson(Map<String, dynamic> json) {
    return TreeModel(
      id: json['id'] as String,
      organizationId: (json['organization_id'] as String?) ?? '',
      driveId: json['drive_id'] as String?,
      registeredByUserId: json['registered_by_user_id'] as String?,
      speciesTa: json['species_ta'] as String?,
      speciesEn: json['species_en'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geographyId: json['geography_id'] as String?,
      plantedDate: DateTime.parse(json['planted_date'] as String),
      photoUrl: json['photo_url'] as String?,
      growthPhotoUrl: json['growth_photo_url'] as String?,
      status: (json['status'] as String?) ?? 'PLANTED',
      notes: json['notes'] as String?,
    );
  }
}
