import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/community_profile_entity.dart';

abstract class CommunityRepository {
  Future<Either<Failure, List<CommunityProfileEntity>>> fetchProfiles();

  /// Raw roster rows for the members screen (it owns its own parsing).
  Future<List<dynamic>> fetchRoster();

  /// The minimal card one member may see of another — names, role, photo,
  /// member-since, journey counts, day-and-month celebrations. Raw map: the
  /// screen owns its parsing and the shape is the backend's own.
  Future<Map<String, dynamic>> fetchMemberCard(String userId);

  /// Who celebrates today (birthdays + anniversaries), opt-outs respected.
  Future<List<dynamic>> fetchCelebrationsToday();
}
