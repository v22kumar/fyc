import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/tournament_model.dart';
import '../models/fixture_model.dart';
import '../models/team_model.dart';
import '../models/challenge_model.dart';
import '../models/player_model.dart';
import '../models/cricket_match_state_model.dart';

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
  Future<List<PlayerModel>> fetchTeamPlayers(String teamId);
  Future<PlayerModel> registerPlayer(String teamId, Map<String, dynamic> data);
  Future<CricketMatchStateModel> fetchCricketMatchState(String fixtureId);
  Future<CricketMatchStateModel> scoreCricketBall(String fixtureId, Map<String, dynamic> data);
  Future<CricketMatchStateModel> undoCricketBall(String fixtureId);
  Future<(CricketMatchStateModel, CricketPlayersModel?)> initCricketMatch(
      String fixtureId, Map<String, dynamic> data);
  Future<(CricketMatchStateModel, CricketPlayersModel?)> startCricketSecondInnings(
      String fixtureId, Map<String, dynamic> data);
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
      throw mapDioException(e);
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
      throw mapDioException(e);
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
      throw mapDioException(e);
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
      throw mapDioException(e);
    }
  }

  @override
  Future<List<PlayerModel>> fetchTeamPlayers(String teamId) async {
    try {
      final response = await _client.dio.get(ApiConstants.sportsTeamPlayers(teamId));
      final list = response.data as List<dynamic>;
      return list.map((e) => PlayerModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<PlayerModel> registerPlayer(String teamId, Map<String, dynamic> data) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.sportsTeamPlayers(teamId),
        data: data,
      );
      return PlayerModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<CricketMatchStateModel> fetchCricketMatchState(String fixtureId) async {
    try {
      final response = await _client.dio.get(ApiConstants.sportsFixtureCricket(fixtureId));
      final data = response.data as Map<String, dynamic>;
      return CricketMatchStateModel.fromJson(data['match_state'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<CricketMatchStateModel> scoreCricketBall(String fixtureId, Map<String, dynamic> data) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.sportsFixtureCricketBall(fixtureId),
        data: data,
      );
      final resData = response.data as Map<String, dynamic>;
      return CricketMatchStateModel.fromJson(resData['match_state'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<CricketMatchStateModel> undoCricketBall(String fixtureId) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.sportsFixtureCricketUndo(fixtureId),
      );
      final resData = response.data as Map<String, dynamic>;
      return CricketMatchStateModel.fromJson(resData['match_state'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<(CricketMatchStateModel, CricketPlayersModel?)> initCricketMatch(
      String fixtureId, Map<String, dynamic> data) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.sportsFixtureCricketInit(fixtureId),
        data: data,
      );
      final resData = response.data as Map<String, dynamic>;
      final match = resData['match'] as Map<String, dynamic>? ?? {};
      final playersJson = resData['current_players'] as Map<String, dynamic>?;
      return (
        CricketMatchStateModel.fromJson(match['match_state'] as Map<String, dynamic>? ?? {}),
        playersJson != null ? CricketPlayersModel.fromJson(playersJson) : null,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<(CricketMatchStateModel, CricketPlayersModel?)> startCricketSecondInnings(
      String fixtureId, Map<String, dynamic> data) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.sportsFixtureCricketSecondInnings(fixtureId),
        data: data,
      );
      final resData = response.data as Map<String, dynamic>;
      final playersJson = resData['current_players'] as Map<String, dynamic>?;
      return (
        CricketMatchStateModel.fromJson(resData['match_state'] as Map<String, dynamic>? ?? {}),
        playersJson != null ? CricketPlayersModel.fromJson(playersJson) : null,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
