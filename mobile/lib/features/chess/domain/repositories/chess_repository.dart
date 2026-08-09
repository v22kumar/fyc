import '../../data/models/chess_game_model.dart';

/// What the chess feature can ask of the server — the seam the pages and
/// blocs bind to, so a test can hand them a fake instead of a Dio.
///
/// The operations still speak in wire models rather than domain entities;
/// mapping 407 lines of ChessGameModel into entities is a separate, larger
/// step. The seam is the part that unblocks testing today.
abstract class ChessRepository {
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
