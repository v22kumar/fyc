import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.phoneNumber,
    super.email,
    required super.role,
    required super.isVerified,
    required super.preferredLanguage,
    super.fullNameEn,
    super.fullNameTa,
    super.dateOfBirth,
    super.gender,
    super.isProfileComplete,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        phoneNumber: json['phone_number'] as String?,
        email: json['email'] as String?,
        role: json['role'] as String,
        isVerified: json['is_verified'] as bool? ?? false,
        preferredLanguage: json['preferred_language'] as String? ?? 'ta',
        fullNameEn: json['full_name_en'] as String?,
        fullNameTa: json['full_name_ta'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        gender: json['gender'] as String?,
        isProfileComplete: json['is_profile_complete'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_number': phoneNumber,
        'email': email,
        'role': role,
        'is_verified': isVerified,
        'preferred_language': preferredLanguage,
        'full_name_en': fullNameEn,
        'full_name_ta': fullNameTa,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'is_profile_complete': isProfileComplete,
      };
}
