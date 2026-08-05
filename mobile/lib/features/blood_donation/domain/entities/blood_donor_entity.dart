import 'package:equatable/equatable.dart';

class BloodDonorEntity extends Equatable {
  final String id;
  final String bloodGroup;
  final bool isAvailable;
  final String? geographyId;
  final String? geographyNameEn;
  final String? geographyNameTa;
  final String? fullNameEn;
  final String? fullNameTa;
  /// Years, not a birth date — a hospital asks how old a donor is.
  final int? age;
  final String? phoneNumber; // only available after authenticated contact request
  /// True for a directory contact imported from Friends2Support (vs a donor who
  /// registered in the app) — drives the "Friends2Support" badge.
  final bool isImported;
  /// 'fyc' (app user — in-app reachable / may be location-aware) or 'imported'
  /// (F2S contact — call only).
  final String tier;
  /// Donation eligibility (90-day cooldown).
  final bool isEligible;
  final String? eligibleOn; // ISO date the donor becomes eligible again
  /// Distance from the query point in km — only set on nearby results.
  final double? distanceKm;
  final bool hasLocation;
  /// Coarse (~1 km) coordinates for the map view — only set on nearby results.
  final double? approxLat;
  final double? approxLng;

  const BloodDonorEntity({
    required this.id,
    required this.bloodGroup,
    required this.isAvailable,
    this.geographyId,
    this.geographyNameEn,
    this.geographyNameTa,
    this.fullNameEn,
    this.fullNameTa,
    this.age,
    this.phoneNumber,
    this.isImported = false,
    this.tier = 'fyc',
    this.isEligible = true,
    this.eligibleOn,
    this.distanceKm,
    this.hasLocation = false,
    this.approxLat,
    this.approxLng,
  });

  String displayName(String lang) =>
      lang == 'ta'
          ? (fullNameTa ?? fullNameEn ?? '—')
          : (fullNameEn ?? fullNameTa ?? '—');

  /// Human-readable location (place/taluk name) — never the raw geography UUID.
  /// The area name, or null when there is none.
  ///
  /// [displayLocation] substitutes a "not specified" placeholder, which is fine
  /// for a field label and wrong for a status line: it filled the most valuable
  /// row on every donor card with a sentence saying nothing.
  String? locationName(String lang) {
    final name = lang == 'ta'
        ? (geographyNameTa ?? geographyNameEn)
        : (geographyNameEn ?? geographyNameTa);
    return (name != null && name.trim().isNotEmpty) ? name : null;
  }

  String displayLocation(String lang) {
    final name = lang == 'ta'
        ? (geographyNameTa ?? geographyNameEn)
        : (geographyNameEn ?? geographyNameTa);
    return (name != null && name.trim().isNotEmpty)
        ? name
        : (lang == 'ta' ? 'இடம் குறிப்பிடப்படவில்லை' : 'Location not set');
  }

  @override
  List<Object?> get props => [
        id,
        bloodGroup,
        isAvailable,
        geographyId,
        geographyNameEn,
        geographyNameTa,
        fullNameEn,
        fullNameTa,
        isImported,
      ];
}
