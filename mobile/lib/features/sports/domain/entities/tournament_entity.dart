import 'package:equatable/equatable.dart';

class TournamentEntity extends Equatable {
  final String id;
  final String nameTa;
  final String nameEn;
  final String sport;
  final int year;
  final String format;
  final String status;

  /// Derived lifecycle phase from the backend:
  /// REGISTRATION_OPEN / REGISTRATION_CLOSED / ONGOING / COMPLETED.
  /// Falls back to [status] when the backend hasn't sent it.
  final String? phase;
  final String? descriptionTa;
  final String? descriptionEn;
  final DateTime? registrationCloseDate;

  const TournamentEntity({
    required this.id,
    required this.nameTa,
    required this.nameEn,
    required this.sport,
    required this.year,
    required this.format,
    required this.status,
    this.phase,
    this.descriptionTa,
    this.descriptionEn,
    this.registrationCloseDate,
  });

  String get effectivePhase => phase ?? status;
  bool get isRegistrationOpen => effectivePhase == 'REGISTRATION_OPEN';
  bool get isRegistrationClosed => effectivePhase == 'REGISTRATION_CLOSED';
  bool get isOngoing => effectivePhase == 'ONGOING';
  bool get isTournamentCompleted => effectivePhase == 'COMPLETED';

  String displayName(String lang) => lang == 'ta' ? nameTa : nameEn;
  String? displayDescription(String lang) =>
      lang == 'ta' ? descriptionTa : descriptionEn;

  @override
  List<Object?> get props => [id, nameTa, nameEn, sport, year, format, status, phase, registrationCloseDate];
}
