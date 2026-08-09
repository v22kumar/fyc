import '../entities/tournament_entities.dart';

/// What the tournament feature can do.
///
/// Every mutation returns the fresh [TournamentDetail], because every action a
/// person takes changes what everyone should be looking at — and a screen that
/// patches its own copy is a screen that drifts from the bracket.
abstract class TournamentRepository {
  Future<List<Tournament>> list();

  Future<TournamentDetail> detail(String id);

  Future<Tournament> create({
    required String name,
    String? description,
    String? registrationDeadline,
    String timeControl,
  });

  /// The clocks an organiser may pick — from the server, so the app never
  /// drifts from what the backend accepts.
  Future<List<({String value, String label})>> timeControlOptions();

  Future<void> register(String id);
  Future<TournamentDetail> decideRegistration(String id, String userId,
      {required bool approve});
  Future<TournamentDetail> closeRegistration(String id);
  Future<TournamentDetail> reopenRegistration(String id);
  Future<TournamentDetail> setTimeControl(String id, String timeControl);
  Future<TournamentDetail> start(String id);
  Future<TournamentDetail> startNextRound(String id);

  Future<TournamentDetail> markReady(String id, String matchId);

  /// Create (or return) the Arena game for a ready match. The caller opens the
  /// board for the returned game id.
  Future<String> play(String id, String matchId);

  Future<TournamentDetail> reportResult(String id, String matchId,
      {required String winnerId});
  Future<TournamentDetail> claimWalkover(String id, String matchId);
  Future<TournamentDetail> setConduct(String id, String matchId,
      {required String mode, String? venue, DateTime? reportingTime});
}
