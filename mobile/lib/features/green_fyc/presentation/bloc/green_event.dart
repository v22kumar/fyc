import 'package:equatable/equatable.dart';

abstract class GreenEvent extends Equatable {
  const GreenEvent();
  @override
  List<Object?> get props => [];
}

class GreenFetchRequested extends GreenEvent {
  const GreenFetchRequested();
}

class GreenTreesRequested extends GreenEvent {
  final String? driveId;
  const GreenTreesRequested({this.driveId});
  @override
  List<Object?> get props => [driveId];
}

class GreenTreeRegistered extends GreenEvent {
  final String? driveId;
  final String? speciesTa;
  final String? speciesEn;
  final double? latitude;
  final double? longitude;
  final DateTime plantedDate;
  final String? photoFilePath; // local device path; BLoC uploads this before registering
  final String? notes;

  const GreenTreeRegistered({
    this.driveId,
    this.speciesTa,
    this.speciesEn,
    this.latitude,
    this.longitude,
    required this.plantedDate,
    this.photoFilePath,
    this.notes,
  });

  @override
  List<Object?> get props =>
      [driveId, speciesTa, speciesEn, latitude, longitude, plantedDate, photoFilePath, notes];
}
