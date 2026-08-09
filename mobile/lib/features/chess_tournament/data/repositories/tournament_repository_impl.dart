import '../../domain/entities/tournament_entities.dart';
import '../../domain/repositories/tournament_repository.dart';
import '../datasources/tournament_datasource.dart';

class TournamentRepositoryImpl implements TournamentRepository {
  TournamentRepositoryImpl(this._source);

  final TournamentDataSource _source;

  @override
  Future<List<Tournament>> list() => _source.list();

  @override
  Future<TournamentDetail> detail(String id) => _source.detail(id);

  @override
  Future<Tournament> create({
    required String name,
    String? description,
    String? registrationDeadline,
    String timeControl = 'rapid_10_0',
  }) =>
      _source.create({
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (registrationDeadline != null)
          'registration_deadline': registrationDeadline,
        'time_control': timeControl,
      });

  @override
  Future<List<({String value, String label})>> timeControlOptions() =>
      _source.timeControlOptions();

  @override
  Future<void> register(String id) => _source.register(id);

  @override
  Future<TournamentDetail> decideRegistration(String id, String userId,
          {required bool approve}) =>
      _source.post(id, 'registrations/$userId/decision', {'approve': approve});

  @override
  Future<TournamentDetail> closeRegistration(String id) =>
      _source.post(id, 'close');

  @override
  Future<TournamentDetail> reopenRegistration(String id) =>
      _source.post(id, 'reopen');

  @override
  Future<TournamentDetail> setTimeControl(String id, String timeControl) =>
      _source.patchSettings(id, {'time_control': timeControl});

  @override
  Future<TournamentDetail> start(String id) => _source.post(id, 'start');

  @override
  Future<TournamentDetail> startNextRound(String id) =>
      _source.post(id, 'next-round');

  @override
  Future<TournamentDetail> markReady(String id, String matchId) =>
      _source.post(id, 'matches/$matchId/ready');

  @override
  Future<String> play(String id, String matchId) => _source.play(id, matchId);

  @override
  Future<TournamentDetail> reportResult(String id, String matchId,
          {required String winnerId}) =>
      _source.post(id, 'matches/$matchId/result', {'winner_id': winnerId});

  @override
  Future<TournamentDetail> claimWalkover(String id, String matchId) =>
      _source.post(id, 'matches/$matchId/claim-walkover');

  @override
  Future<TournamentDetail> setConduct(String id, String matchId,
          {required String mode, String? venue, DateTime? reportingTime}) =>
      _source.post(id, 'matches/$matchId/conduct', {
        'mode': mode,
        if (venue != null) 'venue': venue,
        if (reportingTime != null)
          'reporting_time': reportingTime.toUtc().toIso8601String(),
      });
}
