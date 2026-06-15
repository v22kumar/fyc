import 'package:equatable/equatable.dart';

abstract class VolunteerCertEvent extends Equatable {
  const VolunteerCertEvent();
  @override
  List<Object?> get props => [];
}

class VolunteerCertFetchRequested extends VolunteerCertEvent {
  const VolunteerCertFetchRequested();
}
