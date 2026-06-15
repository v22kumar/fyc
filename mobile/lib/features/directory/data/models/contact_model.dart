import '../../domain/entities/contact_entity.dart';

class ContactModel extends ContactEntity {
  const ContactModel({
    required super.id,
    required super.category,
    required super.nameTa,
    required super.nameEn,
    super.designationTa,
    super.designationEn,
    required super.phonePrimary,
    super.phoneSecondary,
    super.whatsappNumber,
    super.addressTa,
    super.addressEn,
    super.geographyId,
    super.geographyNameEn,
    super.geographyNameTa,
    super.isActive,
    super.displayOrder,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String,
      category: (json['category'] as String?) ?? 'OTHER',
      nameTa: (json['name_ta'] as String?) ?? '',
      nameEn: (json['name_en'] as String?) ?? '',
      designationTa: json['designation_ta'] as String?,
      designationEn: json['designation_en'] as String?,
      phonePrimary: (json['phone_primary'] as String?) ?? '',
      phoneSecondary: json['phone_secondary'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      addressTa: json['address_ta'] as String?,
      addressEn: json['address_en'] as String?,
      geographyId: json['geography_id'] as String?,
      geographyNameEn: json['geography_name_en'] as String?,
      geographyNameTa: json['geography_name_ta'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      displayOrder: (json['display_order'] as int?) ?? 0,
    );
  }
}
