import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_tournaments_usecase.dart';
import '../../domain/usecases/submit_challenge_usecase.dart';
import '../../domain/repositories/sports_repository.dart';
import 'sports_event.dart';
import 'sports_state.dart';

class SportsBloc extends Bloc<SportsEvent, SportsState> {
  final FetchTournamentsUseCase _fetchTournaments;
  final SubmitChallengeUseCase _submitChallenge;
  final SportsRepository _repository;

  SportsBloc({
    required FetchTournamentsUseCase fetchTournaments,
    required SubmitChallengeUseCase submitChallenge,
    required SportsRepository repository,
  })  : _fetchTournaments = fetchTournaments,
        _submitChallenge = submitChallenge,
        _repository = repository,
        super(const SportsInitial()) {
    on<SportsFetchRequested>(_onFetch);
    on<SportsTournamentSelected>(_onTournamentSelected);
    on<SportsChallengeSubmitted>(_onChallengeSubmitted);
  }

  Future<void> _onFetch(
    SportsFetchRequested event,
    Emitter<SportsState> emit,
  ) async {
    emit(const SportsLoading());
    final result = await _fetchTournaments(sport: event.sport);
    result.fold(
      (f) => emit(SportsFailure(f.message)),
      (tournaments) => emit(SportsLoaded(tournaments)),
    );
  }

  Future<void> _onTournamentSelected(
    SportsTournamentSelected event,
    Emitter<SportsState> emit,
  ) async {
    emit(const SportsLoading());
    final fixturesResult = await _repository.fetchFixtures(event.tournamentId);
    final fixtures = fixturesResult.fold((f) => null, (list) => list);
    if (fixtures == null) {
      emit(SportsFailure(
        fixturesResult.fold((f) => f.message, (_) => 'Error'),
      ));
      return;
    }
    final standingsResult =
        await _repository.fetchStandings(event.tournamentId);
    standingsResult.fold(
      (f) => emit(SportsFailure(f.message)),
      (standings) => emit(SportsDetailLoaded(
        fixtures: fixtures,
        standings: standings,
      )),
    );
  }

  Future<void> _onChallengeSubmitted(
    SportsChallengeSubmitted event,
    Emitter<SportsState> emit,
  ) async {
    emit(const SportsLoading());
    final result = await _submitChallenge(
      challengerTeamName: event.challengerTeamName,
      challengerCaptain: event.challengerCaptain,
      challengerPhone: event.challengerPhone,
      sport: event.sport,
      proposedDate: event.proposedDate,
      venue: event.venue,
      message: event.message,
    );
    result.fold(
      (f) => emit(SportsFailure(f.message)),
      (challenge) => emit(SportsChallengeSuccess(challenge.status)),
    );
  }
}
