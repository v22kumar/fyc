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

  /// 'club' (members who registered here) or 'imported' (Friends2Support
  /// contacts). Null means both, which is only right for a count.
  final String? source;

  const BloodDonorSearchRequested({
    this.bloodGroup,
    this.geographyId,
    this.nearby = false,
    this.availableOnly = true,
    this.source,
  });

  @override
  List<Object?> get props =>
      [bloodGroup, geographyId, nearby, availableOnly, source];
}

class BloodDonorRegisterRequested extends BloodDonorEvent {
  final String bloodGroup;
  final bool isAvailable;
  final DateTime? lastDonationDate;
  final double? latitude;
  final double? longitude;
  final bool locationConsent;
  final bool notifyOptIn;

  const BloodDonorRegisterRequested({
    required this.bloodGroup,
    this.isAvailable = true,
    this.lastDonationDate,
    this.latitude,
    this.longitude,
    this.locationConsent = false,
    this.notifyOptIn = true,
  });

  @override
  List<Object?> get props =>
      [bloodGroup, isAvailable, lastDonationDate, latitude, longitude, locationConsent, notifyOptIn];
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

/// Rank donors by how near they actually are.
///
/// The taluk filter answers "who is in this administrative area", which is not
/// the question someone at a hospital is asking. This one is.
class BloodDonorNearbyRequested extends BloodDonorEvent {
  final double lat;
  final double lng;
  final String? bloodGroup;

  const BloodDonorNearbyRequested({
    required this.lat,
    required this.lng,
    this.bloodGroup,
  });

  @override
  List<Object?> get props => [lat, lng, bloodGroup];
}
