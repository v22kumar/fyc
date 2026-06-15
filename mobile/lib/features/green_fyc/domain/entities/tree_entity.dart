import 'package:equatable/equatable.dart';

class TreeEntity extends Equatable {
  final String id;
  final String organizationId;
  final String? driveId;
  final String? registeredByUserId;
  final String? speciesTa;
  final String? speciesEn;
  final double? latitude;
  final double? longitude;
  final String? geographyId;
  final DateTime plantedDate;
  final String? photoUrl;
  final String? growthPhotoUrl;
  final String status;
  final String? notes;

  const TreeEntity({
    required this.id,
    required this.organizationId,
    this.driveId,
    this.registeredByUserId,
    this.speciesTa,
    this.speciesEn,
    this.latitude,
    this.longitude,
    this.geographyId,
    required this.plantedDate,
    this.photoUrl,
    this.growthPhotoUrl,
    required this.status,
    this.notes,
  });

  String? displaySpecies(String lang) => lang == 'ta' ? speciesTa : speciesEn;

  @override
  List<Object?> get props =>
      [id, driveId, speciesTa, speciesEn, plantedDate, status];
}
