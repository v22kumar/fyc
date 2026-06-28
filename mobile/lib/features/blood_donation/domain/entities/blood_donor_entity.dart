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
  final String? phoneNumber; // only available after authenticated contact request

  const BloodDonorEntity({
    required this.id,
    required this.bloodGroup,
    required this.isAvailable,
    this.geographyId,
    this.geographyNameEn,
    this.geographyNameTa,
    this.fullNameEn,
    this.fullNameTa,
    this.phoneNumber,
  });

  String displayName(String lang) =>
      lang == 'ta'
          ? (fullNameTa ?? fullNameEn ?? '—')
          : (fullNameEn ?? fullNameTa ?? '—');

  /// Human-readable location (place/taluk name) — never the raw geography UUID.
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
      ];
}
