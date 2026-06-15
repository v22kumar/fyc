import 'dart:typed_data';
import 'package:equatable/equatable.dart';

abstract class VolunteerCertState extends Equatable {
  const VolunteerCertState();
  @override
  List<Object?> get props => [];
}

class VolunteerCertInitial extends VolunteerCertState {
  const VolunteerCertInitial();
}

class VolunteerCertLoading extends VolunteerCertState {
  const VolunteerCertLoading();
}

class VolunteerCertLoaded extends VolunteerCertState {
  final Uint8List bytes;
  const VolunteerCertLoaded(this.bytes);
  @override
  List<Object?> get props => [bytes.length];
}

class VolunteerCertFailure extends VolunteerCertState {
  final String message;
  const VolunteerCertFailure(this.message);
  @override
  List<Object?> get props => [message];
}
