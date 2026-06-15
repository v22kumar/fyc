import 'package:equatable/equatable.dart';

class CommunityProfileEntity extends Equatable {
  final String id;
  final String userId;
  final String category;
  final String? businessNameTa;
  final String? businessNameEn;
  final String? descriptionTa;
  final String? descriptionEn;
  final String? contactPhone;
  final String? contactWhatsapp;
  final String? serviceArea;
  final int? yearsExperience;
  final bool isAvailable;
  final bool isVerified;
  final String? fullNameEn;
  final String? fullNameTa;

  const CommunityProfileEntity({
    required this.id,
    required this.userId,
    required this.category,
    this.businessNameTa,
    this.businessNameEn,
    this.descriptionTa,
    this.descriptionEn,
    this.contactPhone,
    this.contactWhatsapp,
    this.serviceArea,
    this.yearsExperience,
    required this.isAvailable,
    required this.isVerified,
    this.fullNameEn,
    this.fullNameTa,
  });

  /// Best display title: business name, falling back to full name.
  String displayName(String lang) {
    final biz = lang == 'ta' ? businessNameTa : businessNameEn;
    if (biz != null && biz.isNotEmpty) return biz;
    final name = lang == 'ta' ? fullNameTa : fullNameEn;
    if (name != null && name.isNotEmpty) return name;
    return businessNameEn ?? businessNameTa ?? fullNameEn ?? fullNameTa ?? '—';
  }

  String? displayDescription(String lang) =>
      lang == 'ta' ? descriptionTa : descriptionEn;

  bool get hasPhone => contactPhone != null && contactPhone!.isNotEmpty;

  @override
  List<Object?> get props => [id, userId, category, isAvailable, isVerified];
}
