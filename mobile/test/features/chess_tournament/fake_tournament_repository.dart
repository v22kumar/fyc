import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/features/chess_tournament/data/models/tournament_models.dart';
import 'package:fyc_connect/features/chess_tournament/domain/entities/tournament_entities.dart';
import 'package:fyc_connect/features/chess_tournament/domain/repositories/tournament_repository.dart';

import 'tournament_fixtures.dart';

/// Serves the canned stages through the real repository seam.
///
/// This is the dependency seam the old implementation lacked: the previous
/// harness had to add `preload` parameters to production widgets because the
/// screens reached into a service locator for a Dio. Screens now take a
/// repository, so a test hands them one — no production code bent for tests.
///
/// Fixtures pass through the real `detailFromJson`, so what the screens are
/// tested rendering is the wire shape the backend actually sends.
class FakeTournamentRepository implements TournamentRepository {
  FakeTournamentRepository(Map<String, dynamic> stage)
      : _detail = detailFromJson(stage);

  TournamentDetail _detail;

  /// What the screen asked for, so tests can assert intent reached the seam.
  final List<String> calls = [];

  /// When set, the next call throws the way a 400 from the round gate does —
  /// with the server's sentence — then resets.
  bool failNext = false;

  void _maybeFail() {
    if (failNext) {
      failNext = false;
      throw const ValidationFailure('Finish the current round first');
    }
  }

  void serve(Map<String, dynamic> stage) => _detail = detailFromJson(stage);

  @override
  Future<TournamentDetail> detail(String id) async {
    calls.add('detail');
    _maybeFail();
    return _detail;
  }

  @override
  Future<List<Tournament>> list() async {
    calls.add('list');
    return [for (final j in stageList) tournamentFromJson(j)];
  }

  @override
  Future<Tournament> create(
      {required String name,
      String? description,
      String? registrationDeadline,
      String timeControl = 'rapid_10_0'}) async {
    calls.add('create');
    return _detail;
  }

  @override
  Future<List<({String value, String label})>> timeControlOptions() async =>
      [(value: 'rapid_10_0', label: 'Rapid — 10 min each')];

  @override
  Future<void> register(String id) async => calls.add('register');

  @override
  Future<TournamentDetail> decideRegistration(String id, String userId,
      {required bool approve}) async {
    calls.add('decide:$userId:$approve');
    return _detail;
  }

  @override
  Future<TournamentDetail> closeRegistration(String id) async {
    calls.add('close');
    return _detail;
  }

  @override
  Future<TournamentDetail> reopenRegistration(String id) async {
    calls.add('reopen');
    return _detail;
  }

  @override
  Future<TournamentDetail> setTimeControl(String id, String timeControl) async {
    calls.add('tc:$timeControl');
    return _detail;
  }

  @override
  Future<TournamentDetail> start(String id) async {
    calls.add('start');
    return _detail;
  }

  @override
  Future<TournamentDetail> startNextRound(String id) async {
    calls.add('next-round');
    _maybeFail();
    return _detail;
  }

  @override
  Future<TournamentDetail> markReady(String id, String matchId) async {
    calls.add('ready:$matchId');
    return _detail;
  }

  @override
  Future<String> play(String id, String matchId) async {
    calls.add('play:$matchId');
    return 'game-1';
  }

  @override
  Future<TournamentDetail> reportResult(String id, String matchId,
      {required String winnerId}) async {
    calls.add('result:$matchId:$winnerId');
    return _detail;
  }

  @override
  Future<TournamentDetail> claimWalkover(String id, String matchId) async {
    calls.add('walkover:$matchId');
    return _detail;
  }

  @override
  Future<TournamentDetail> setConduct(String id, String matchId,
      {required String mode, String? venue, DateTime? reportingTime}) async {
    calls.add('conduct:$matchId:$mode');
    return _detail;
  }
}
