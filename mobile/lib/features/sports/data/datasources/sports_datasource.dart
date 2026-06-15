import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/tournament_model.dart';
import '../models/fixture_model.dart';
import '../models/team_model.dart';
import '../models/challenge_model.dart';

abstract class SportsDataSource {
  Future<List<TournamentModel>> fetchTournaments({String? sport});
  Future<List<FixtureModel>> fetchFixtures(String tournamentId);
  Future<List<TeamModel>> fetchStandings(String tournamentId);
  Future<ChallengeModel> submitChallenge({
    required String challengerTeamName,
    required String challengerCaptain,
    required String challengerPhone,
    required String sport,
    DateTime? proposedDate,
    String? venue,
    String? message,
  });
}

class SportsDataSourceImpl implements SportsDataSource {
  final ApiClient _client;
  SportsDataSourceImpl(this._client);

  @override
  Future<List<TournamentModel>> fetchTournaments({String? sport}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.sportsTournaments,
        queryParameters: (sport != null && sport.isNotEmpty)
            ? {'sport': sport}
            : null,
      );
      final list = response.data as List<dynamic>;
      return list
          .map((e) => TournamentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<List<FixtureModel>> fetchFixtures(String tournamentId) async {
    try {
      final response = await _client.dio
          .get('${ApiConstants.sportsTournaments}/$tournamentId/fixtures');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => FixtureModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<List<TeamModel>> fetchStandings(String tournamentId) async {
    try {
      final response = await _client.dio
          .get('${ApiConstants.sportsTournaments}/$tournamentId/standings');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => TeamModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<ChallengeModel> submitChallenge({
    required String challengerTeamName,
    required String challengerCaptain,
    required String challengerPhone,
    required String sport,
    DateTime? proposedDate,
    String? venue,
    String? message,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.sportsChallenges,
        data: {
          'challenger_team_name': challengerTeamName,
          'challenger_captain': challengerCaptain,
          'challenger_phone': challengerPhone,
          'sport': sport,
          if (proposedDate != null)
            'proposed_date': proposedDate.toUtc().toIso8601String(),
          if (venue != null && venue.isNotEmpty) 'venue': venue,
          if (message != null && message.isNotEmpty) 'message': message,
        },
      );
      return ChallengeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Failure _map(DioException e) {
    if (e.type == DioExceptionType.connectionError) return const NetworkFailure();
    final detail = (e.response?.data as Map?)?['detail'] as String? ?? 'Error';
    if (e.response?.statusCode == 401) return AuthFailure(detail);
    return ServerFailure(detail);
  }
}
