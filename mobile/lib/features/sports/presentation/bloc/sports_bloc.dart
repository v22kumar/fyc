import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_tournaments_usecase.dart';
import '../../domain/usecases/submit_challenge_usecase.dart';
import '../../domain/repositories/sports_repository.dart';
import 'sports_event.dart';
import 'sports_state.dart';
import '../../domain/entities/tournament_entity.dart';

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
    on<SportsWeeklyGameCreateRequested>(_onCreateWeeklyGame);
    on<SportsWeeklyGameJoinRequested>(_onJoinWeeklyGame);
    on<SportsWeeklyGameStartRequested>(_onStartWeeklyGame);
  }

  Future<void> _onFetch(
    SportsFetchRequested event,
    Emitter<SportsState> emit,
  ) async {
    emit(const SportsLoading());
    if (event.filter == 'weekly_games') {
      final result = await _repository.fetchWeeklyGames();
      result.fold(
        (f) => emit(SportsFailure(f.message)),
        (games) => emit(SportsLoaded(weeklyGames: games)),
      );
    } else {
      final result = await _fetchTournaments(sport: event.sport);
      result.fold(
        (f) => emit(SportsFailure(f.message)),
        (tournaments) => emit(SportsLoaded(tournaments: tournaments)),
      );
    }
  }

  Future<void> _onTournamentSelected(
    SportsTournamentSelected event,
    Emitter<SportsState> emit,
  ) async {
    TournamentEntity? tournament;
    if (state is SportsLoaded) {
      final list = (state as SportsLoaded).tournaments;
      tournament = list.where((t) => t.id == event.tournamentId).firstOrNull;
    } else if (state is SportsDetailLoaded && (state as SportsDetailLoaded).tournament.id == event.tournamentId) {
      tournament = (state as SportsDetailLoaded).tournament;
    }

    emit(const SportsLoading());

    if (tournament == null) {
      final tResult = await _fetchTournaments();
      tResult.fold(
        (f) => null,
        (list) => tournament = list.where((t) => t.id == event.tournamentId).firstOrNull,
      );
    }

    if (tournament == null) {
      emit(const SportsFailure('Tournament not found'));
      return;
    }

    // Fire fixtures + standings concurrently (they're independent) and await
    // both, instead of one-then-the-other — halves the round-trip wait before
    // the detail screen can render.
    final fixturesFuture = _repository.fetchFixtures(event.tournamentId);
    final standingsFuture = _repository.fetchStandings(event.tournamentId);
    final fixturesResult = await fixturesFuture;
    final standingsResult = await standingsFuture;

    final fixtures = fixturesResult.fold((f) => null, (list) => list);
    if (fixtures == null) {
      emit(SportsFailure(
        fixturesResult.fold((f) => f.message, (_) => 'Error'),
      ));
      return;
    }
    standingsResult.fold(
      (f) => emit(SportsFailure(f.message)),
      (standings) => emit(SportsDetailLoaded(
        tournament: tournament!,
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

  Future<void> _onJoinWeeklyGame(
    SportsWeeklyGameJoinRequested event,
    Emitter<SportsState> emit,
  ) async {
    final currentState = state;
    if (currentState is SportsLoaded) {
      emit(const SportsLoading());
      final result = await _repository.joinWeeklyGame(event.gameId);
      result.fold(
        (f) => emit(SportsFailure(f.message)),
        (updatedGame) {
          final updatedList = currentState.weeklyGames.map((g) {
            return g.id == updatedGame.id ? updatedGame : g;
          }).toList();
          emit(SportsLoaded(tournaments: currentState.tournaments, weeklyGames: updatedList));
        },
      );
    }
  }

  Future<void> _onStartWeeklyGame(
    SportsWeeklyGameStartRequested event,
    Emitter<SportsState> emit,
  ) async {
    final currentState = state;
    if (currentState is SportsLoaded) {
      emit(const SportsLoading());
      final result = await _repository.startWeeklyGame(event.gameId);
      result.fold(
        (f) => emit(SportsFailure(f.message)),
        (updatedGame) {
          final updatedList = currentState.weeklyGames.map((g) {
            return g.id == updatedGame.id ? updatedGame : g;
          }).toList();
          emit(SportsLoaded(tournaments: currentState.tournaments, weeklyGames: updatedList));
        },
      );
    }
  }

  Future<void> _onCreateWeeklyGame(
    SportsWeeklyGameCreateRequested event,
    Emitter<SportsState> emit,
  ) async {
    final currentState = state;
    if (currentState is SportsLoaded) {
      emit(const SportsLoading());
      final result = await _repository.createWeeklyGame(event.data);
      result.fold(
        (f) => emit(SportsFailure(f.message)),
        (newGame) {
          final updatedList = [newGame, ...currentState.weeklyGames];
          emit(SportsLoaded(tournaments: currentState.tournaments, weeklyGames: updatedList));
        },
      );
    }
  }
}
