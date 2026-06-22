import 'package:equatable/equatable.dart';

abstract class IssueEvent extends Equatable {
  const IssueEvent();
  @override
  List<Object?> get props => [];
}

class IssueSubmitRequested extends IssueEvent {
  final String category;
  final String descriptionTa;
  final String descriptionEn;
  final double latitude;
  final double longitude;
  final String? photoUrl;
  final bool isEmergency;

  const IssueSubmitRequested({
    required this.category,
    required this.descriptionTa,
    required this.descriptionEn,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    this.isEmergency = false,
  });

  @override
  List<Object?> get props =>
      [category, descriptionTa, descriptionEn, latitude, longitude, photoUrl, isEmergency];
}
