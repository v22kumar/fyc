import 'package:equatable/equatable.dart';

class TournamentEntity extends Equatable {
  final String id;
  final String nameTa;
  final String nameEn;
  final String sport;
  final int year;
  final String format;
  final String status;
  final String? descriptionTa;
  final String? descriptionEn;

  const TournamentEntity({
    required this.id,
    required this.nameTa,
    required this.nameEn,
    required this.sport,
    required this.year,
    required this.format,
    required this.status,
    this.descriptionTa,
    this.descriptionEn,
  });

  String displayName(String lang) => lang == 'ta' ? nameTa : nameEn;
  String? displayDescription(String lang) =>
      lang == 'ta' ? descriptionTa : descriptionEn;

  @override
  List<Object?> get props => [id, nameTa, nameEn, sport, year, format, status];
}
