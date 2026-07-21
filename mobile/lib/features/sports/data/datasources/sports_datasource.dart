import 'dart:convert';
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
import '../models/weekly_game_model.dart';

abstract class SportsDataSource {
  Future<List<TournamentModel>> fetchTournaments({String? sport});
  Future<List<FixtureModel>> fetchFixtures(String tournamentId);
  Future<List<TeamModel>> fetchStandings(String tournamentId);
  Future<FixtureModel> submitFixtureResult(
    String tournamentId,
    String fixtureId, {
    String? teamAScore,
    String? teamBScore,
    String? winnerId,
    String? notes,
  });
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
  Stream<CricketMatchStateModel> streamCricketMatchState(String fixtureId);
  Future<CricketMatchStateModel> scoreCricketBall(String fixtureId, Map<String, dynamic> data);
  Future<CricketMatchStateModel> editCricketBall(String fixtureId, String ballId, Map<String, dynamic> data);
  Future<CricketMatchStateModel> undoEditBall(String fixtureId, String ballId);
  Future<CricketMatchStateModel> undoCricketBall(String fixtureId);
  Future<(CricketMatchStateModel, CricketPlayersModel?)> initCricketMatch(
      String fixtureId, Map<String, dynamic> data);
  Future<(CricketMatchStateModel, CricketPlayersModel?)> startCricketSecondInnings(
      String fixtureId, Map<String, dynamic> data);
      
  Future<List<WeeklyGameModel>> fetchWeeklyGames();
  Future<WeeklyGameModel> createWeeklyGame(Map<String, dynamic> data);
  Future<WeeklyGameModel> joinWeeklyGame(String gameId);
  Future<WeeklyGameModel> startWeeklyGame(String gameId);
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
  Future<FixtureModel> submitFixtureResult(
    String tournamentId,
    String fixtureId, {
    String? teamAScore,
    String? teamBScore,
    String? winnerId,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.sportsFixtureResult(tournamentId, fixtureId),
        data: {
          'team_a_score': teamAScore,
          'team_b_score': teamBScore,
          'winner_id': winnerId,
          'result_notes': notes,
        },
      );
      return FixtureModel.fromJson(response.data as Map<String, dynamic>);
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
  Stream<CricketMatchStateModel> streamCricketMatchState(String fixtureId) async* {
    // Server-Sent Events: one long-lived connection that pushes the scoreboard
    // as it changes, instead of re-polling every few seconds. Parsed with the
    // same match_state mapping as the one-shot fetch.
    final response = await _client.dio.get<ResponseBody>(
      ApiConstants.sportsFixtureCricketStream(fixtureId),
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
        // Never time out an intentionally idle stream between deliveries.
        receiveTimeout: Duration.zero,
      ),
    );
    final body = response.data;
    if (body == null) return;
    var buffer = '';
    await for (final chunk in body.stream) {
      buffer += utf8.decode(chunk, allowMalformed: true);
      int nl;
      while ((nl = buffer.indexOf('\n')) != -1) {
        final line = buffer.substring(0, nl).trimRight();
        buffer = buffer.substring(nl + 1);
        if (!line.startsWith('data:')) continue; // skip ": ping" / "retry:" lines
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        try {
          final map = json.decode(payload) as Map<String, dynamic>;
          final ms = map['match_state'];
          if (ms is Map<String, dynamic>) {
            yield CricketMatchStateModel.fromJson(ms);
          }
        } catch (_) {
          // Ignore a malformed frame; the next delivery (or the poll fallback) recovers.
        }
      }
    }
  }

  @override
  Future<CricketMatchStateModel> scoreCricketBall(String fixtureId, Map<String, dynamic> data) async {
    try {
      final response = await _client.dio.post(ApiConstants.sportsFixtureCricketBall(fixtureId), data: data);
      final resData = response.data as Map<String, dynamic>;
      return CricketMatchStateModel.fromJson(resData['match_state'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<CricketMatchStateModel> editCricketBall(String fixtureId, String ballId, Map<String, dynamic> data) async {
    try {
      final response = await _client.dio.put('${ApiConstants.sportsFixtureCricket(fixtureId)}/ball/$ballId', data: data);
      final resData = response.data as Map<String, dynamic>;
      return CricketMatchStateModel.fromJson(resData['match_state'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<CricketMatchStateModel> undoEditBall(String fixtureId, String ballId) async {
    try {
      final response = await _client.dio.post('${ApiConstants.sportsFixtureCricket(fixtureId)}/ball/$ballId/undo-edit');
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

  @override
  Future<List<WeeklyGameModel>> fetchWeeklyGames() async {
    try {
      final response = await _client.dio.get(ApiConstants.weeklyGames);
      final list = response.data as List<dynamic>;
      return list.map((e) => WeeklyGameModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<WeeklyGameModel> createWeeklyGame(Map<String, dynamic> data) async {
    try {
      final response = await _client.dio.post(ApiConstants.weeklyGames, data: data);
      return WeeklyGameModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<WeeklyGameModel> joinWeeklyGame(String gameId) async {
    try {
      final response = await _client.dio.post(ApiConstants.weeklyGameJoin(gameId));
      return WeeklyGameModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<WeeklyGameModel> startWeeklyGame(String gameId) async {
    try {
      final response = await _client.dio.post(ApiConstants.weeklyGameStart(gameId));
      return WeeklyGameModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
