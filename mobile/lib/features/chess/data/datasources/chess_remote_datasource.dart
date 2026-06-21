import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/dio_error_mapper.dart';
import '../../../../core/network/api_client.dart';
import '../models/chess_game_model.dart';

abstract class ChessRemoteDataSource {
  Future<ChessGameModel> submitGame(Map<String, dynamic> payload);
  Future<List<ChessGameModel>> myGames({int limit = 30});
  Future<ChessStatsModel> myStats();
  Future<ChessGameDetailModel> getGame(String gameId);
  Future<List<ChessMemberModel>> members();
  Future<ChessChallengeModel> sendChallenge({
    required String challengedId,
    required String timeControl,
    String? message,
  });
  Future<List<ChessChallengeModel>> incomingChallenges();
  Future<List<ChessChallengeModel>> outgoingChallenges();
  Future<ChallengeAcceptResult> acceptChallenge(String challengeId);
  Future<void> declineChallenge(String challengeId);
  Future<List<LiveGameModel>> liveGames();
  Future<WeeklyAwardsModel> weeklyAwards();
}

class ChessRemoteDataSourceImpl implements ChessRemoteDataSource {
  final ApiClient _client;

  ChessRemoteDataSourceImpl(this._client);

  @override
  Future<ChessGameModel> submitGame(Map<String, dynamic> payload) async {
    try {
      final response = await _client.dio.post(ApiConstants.chessGames, data: payload);
      return ChessGameModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<ChessGameModel>> myGames({int limit = 30}) async {
    try {
      final response = await _client.dio.get(
        ApiConstants.chessMyGames,
        queryParameters: {'limit': limit},
      );
      return (response.data as List)
          .map((e) => ChessGameModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ChessStatsModel> myStats() async {
    try {
      final response = await _client.dio.get(ApiConstants.chessMyStats);
      return ChessStatsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ChessGameDetailModel> getGame(String gameId) async {
    try {
      final response =
          await _client.dio.get('${ApiConstants.chessGames}/$gameId');
      return ChessGameDetailModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<ChessMemberModel>> members() async {
    try {
      final response = await _client.dio.get(ApiConstants.chessMembers);
      return (response.data as List)
          .map((e) => ChessMemberModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ChessChallengeModel> sendChallenge({
    required String challengedId,
    required String timeControl,
    String? message,
  }) async {
    try {
      final response = await _client.dio.post(
        ApiConstants.chessChallenges,
        data: {
          'challenged_id': challengedId,
          'time_control': timeControl,
          if (message != null) 'message': message,
        },
      );
      return ChessChallengeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<ChessChallengeModel>> incomingChallenges() async {
    try {
      final response = await _client.dio.get(ApiConstants.chessChallengesIncoming);
      return (response.data as List)
          .map((e) => ChessChallengeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<ChessChallengeModel>> outgoingChallenges() async {
    try {
      final response = await _client.dio.get(ApiConstants.chessChallengesOutgoing);
      return (response.data as List)
          .map((e) => ChessChallengeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<ChallengeAcceptResult> acceptChallenge(String challengeId) async {
    try {
      final response = await _client.dio.post(
        '${ApiConstants.chessChallenges}/$challengeId/accept',
      );
      return ChallengeAcceptResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<void> declineChallenge(String challengeId) async {
    try {
      await _client.dio.post(
        '${ApiConstants.chessChallenges}/$challengeId/decline',
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<List<LiveGameModel>> liveGames() async {
    try {
      final response = await _client.dio.get(ApiConstants.chessLiveGames);
      return (response.data as List)
          .map((e) => LiveGameModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  @override
  Future<WeeklyAwardsModel> weeklyAwards() async {
    try {
      final response = await _client.dio.get(ApiConstants.chessAwardsWeekly);
      return WeeklyAwardsModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
