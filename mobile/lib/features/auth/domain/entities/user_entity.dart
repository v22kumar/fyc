import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? phoneNumber;
  final String? email;
  final String role;
  final bool isVerified;
  final String preferredLanguage;
  final String? fullNameEn;
  final String? fullNameTa;
  final String? dateOfBirth;
  final String? gender;
  final bool isProfileComplete;

  const UserEntity({
    required this.id,
    this.phoneNumber,
    this.email,
    required this.role,
    required this.isVerified,
    required this.preferredLanguage,
    this.fullNameEn,
    this.fullNameTa,
    this.dateOfBirth,
    this.gender,
    this.isProfileComplete = false,
  });

  bool get isAdmin =>
      role == 'ADMIN' || role == 'SUPER_ADMIN' || role == 'EXECUTIVE_MEMBER';

  bool get isVolunteer => role == 'VOLUNTEER';

  bool get isMember => role == 'CLUB_MEMBER' || isAdmin;

  @override
  List<Object?> get props =>
      [id, phoneNumber, email, role, isVerified, preferredLanguage,
       fullNameEn, fullNameTa, dateOfBirth, gender, isProfileComplete];
}
