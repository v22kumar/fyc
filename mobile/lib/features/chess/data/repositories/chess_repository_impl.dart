import '../../domain/repositories/chess_repository.dart';
import '../datasources/chess_remote_datasource.dart';
import '../models/chess_game_model.dart';

/// Thin delegation — the datasource already speaks the wire; the value of the
/// class is the domain-level interface the rest of the feature binds to.
class ChessRepositoryImpl implements ChessRepository {
  ChessRepositoryImpl(this._remote);

  final ChessRemoteDataSource _remote;

  @override
  Future<ChessGameModel> submitGame(Map<String, dynamic> payload) =>
      _remote.submitGame(payload);

  @override
  Future<List<ChessGameModel>> myGames({int limit = 30}) =>
      _remote.myGames(limit: limit);

  @override
  Future<ChessStatsModel> myStats() => _remote.myStats();

  @override
  Future<ChessGameDetailModel> getGame(String gameId) =>
      _remote.getGame(gameId);

  @override
  Future<List<ChessMemberModel>> members() => _remote.members();

  @override
  Future<ChessChallengeModel> sendChallenge({
    required String challengedId,
    required String timeControl,
    String? message,
  }) =>
      _remote.sendChallenge(
          challengedId: challengedId,
          timeControl: timeControl,
          message: message);

  @override
  Future<List<ChessChallengeModel>> incomingChallenges() =>
      _remote.incomingChallenges();

  @override
  Future<List<ChessChallengeModel>> outgoingChallenges() =>
      _remote.outgoingChallenges();

  @override
  Future<ChallengeAcceptResult> acceptChallenge(String challengeId) =>
      _remote.acceptChallenge(challengeId);

  @override
  Future<void> declineChallenge(String challengeId) =>
      _remote.declineChallenge(challengeId);

  @override
  Future<List<LiveGameModel>> liveGames() => _remote.liveGames();

  @override
  Future<WeeklyAwardsModel> weeklyAwards() => _remote.weeklyAwards();
}
