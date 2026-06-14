import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String phoneNumber;
  final String role;
  final bool isVerified;
  final String preferredLanguage;

  const UserEntity({
    required this.id,
    required this.phoneNumber,
    required this.role,
    required this.isVerified,
    required this.preferredLanguage,
  });

  bool get isAdmin =>
      role == 'ADMIN' || role == 'SUPER_ADMIN' || role == 'EXECUTIVE_MEMBER';

  bool get isVolunteer => role == 'VOLUNTEER';

  bool get isMember => role == 'CLUB_MEMBER' || isAdmin;

  @override
  List<Object?> get props =>
      [id, phoneNumber, role, isVerified, preferredLanguage];
}
