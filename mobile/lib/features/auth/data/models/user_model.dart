import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.phoneNumber,
    required super.role,
    required super.isVerified,
    required super.preferredLanguage,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        phoneNumber: json['phone_number'] as String,
        role: json['role'] as String,
        isVerified: json['is_verified'] as bool? ?? false,
        preferredLanguage: json['preferred_language'] as String? ?? 'ta',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_number': phoneNumber,
        'role': role,
        'is_verified': isVerified,
        'preferred_language': preferredLanguage,
      };
}
