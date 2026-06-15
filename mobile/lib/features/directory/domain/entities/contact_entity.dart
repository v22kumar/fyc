import 'package:equatable/equatable.dart';

class ContactEntity extends Equatable {
  final String id;
  final String category;
  final String nameTa;
  final String nameEn;
  final String? designationTa;
  final String? designationEn;
  final String phonePrimary;
  final String? phoneSecondary;
  final String? whatsappNumber;
  final String? addressTa;
  final String? addressEn;
  final String? geographyId;
  final String? geographyNameEn;
  final String? geographyNameTa;
  final bool isActive;
  final int displayOrder;

  const ContactEntity({
    required this.id,
    required this.category,
    required this.nameTa,
    required this.nameEn,
    this.designationTa,
    this.designationEn,
    required this.phonePrimary,
    this.phoneSecondary,
    this.whatsappNumber,
    this.addressTa,
    this.addressEn,
    this.geographyId,
    this.geographyNameEn,
    this.geographyNameTa,
    this.isActive = true,
    this.displayOrder = 0,
  });

  String displayName(String lang) => lang == 'ta' ? nameTa : nameEn;

  String? displayDesignation(String lang) =>
      lang == 'ta' ? designationTa : designationEn;

  String? displayGeography(String lang) =>
      lang == 'ta' ? geographyNameTa : geographyNameEn;

  String? displayAddress(String lang) => lang == 'ta' ? addressTa : addressEn;

  bool get hasWhatsApp =>
      whatsappNumber != null && whatsappNumber!.trim().isNotEmpty;

  String get categoryEmoji => categoryEmojiFor(category);

  String categoryLabel(String lang) => categoryLabelFor(category, lang);

  static String categoryEmojiFor(String category) {
    switch (category) {
      case 'POLICE':
        return '👮';
      case 'FIRE':
        return '🚒';
      case 'AMBULANCE':
        return '🚑';
      case 'HOSPITAL':
        return '🏥';
      case 'ELECTRICITY_BOARD':
        return '⚡';
      case 'REVENUE_OFFICE':
        return '🏛️';
      case 'TALUK_OFFICE':
        return '🏢';
      case 'RTO':
        return '🚗';
      case 'MUNICIPALITY':
        return '🏙️';
      case 'CM_HELPLINE':
        return '☎️';
      case 'OTHER':
      default:
        return '📌';
    }
  }

  static String categoryLabelFor(String category, String lang) {
    final ta = lang == 'ta';
    switch (category) {
      case 'POLICE':
        return ta ? 'காவல்துறை' : 'Police';
      case 'FIRE':
        return ta ? 'தீயணைப்புத் துறை' : 'Fire';
      case 'AMBULANCE':
        return ta ? 'ஆம்புலன்ஸ்' : 'Ambulance';
      case 'HOSPITAL':
        return ta ? 'மருத்துவமனை' : 'Hospital';
      case 'ELECTRICITY_BOARD':
        return ta ? 'மின்வாரியம்' : 'Electricity Board';
      case 'REVENUE_OFFICE':
        return ta ? 'வருவாய்த் துறை' : 'Revenue Office';
      case 'TALUK_OFFICE':
        return ta ? 'வட்டாட்சியர் அலுவலகம்' : 'Taluk Office';
      case 'RTO':
        return ta ? 'போக்குவரத்து அலுவலகம்' : 'RTO';
      case 'MUNICIPALITY':
        return ta ? 'நகராட்சி' : 'Municipality';
      case 'CM_HELPLINE':
        return ta ? 'முதலமைச்சர் உதவி எண்' : 'CM Helpline';
      case 'OTHER':
      default:
        return ta ? 'மற்றவை' : 'Other';
    }
  }

  @override
  List<Object?> get props => [
        id,
        category,
        nameTa,
        nameEn,
        phonePrimary,
        whatsappNumber,
        geographyId,
        displayOrder,
      ];
}
