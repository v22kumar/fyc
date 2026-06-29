import 'package:equatable/equatable.dart';

abstract class BloodDonorEvent extends Equatable {
  const BloodDonorEvent();
  @override
  List<Object?> get props => [];
}

class BloodDonorSearchRequested extends BloodDonorEvent {
  final String? bloodGroup;
  final String? geographyId;
  final bool nearby;
  final bool availableOnly;
  const BloodDonorSearchRequested({
    this.bloodGroup,
    this.geographyId,
    this.nearby = false,
    this.availableOnly = true,
  });

  @override
  List<Object?> get props => [bloodGroup, geographyId, nearby, availableOnly];
}

class BloodDonorRegisterRequested extends BloodDonorEvent {
  final String bloodGroup;
  final bool isAvailable;
  final DateTime? lastDonationDate;

  const BloodDonorRegisterRequested({
    required this.bloodGroup,
    this.isAvailable = true,
    this.lastDonationDate,
  });

  @override
  List<Object?> get props => [bloodGroup, isAvailable, lastDonationDate];
}

class BloodDonorContactRequested extends BloodDonorEvent {
  final String donorId;
  const BloodDonorContactRequested(this.donorId);

  @override
  List<Object?> get props => [donorId];
}

class BloodDonorAvailabilityUpdated extends BloodDonorEvent {
  final String donorId;
  final bool isAvailable;
  const BloodDonorAvailabilityUpdated({
    required this.donorId,
    required this.isAvailable,
  });

  @override
  List<Object?> get props => [donorId, isAvailable];
}
