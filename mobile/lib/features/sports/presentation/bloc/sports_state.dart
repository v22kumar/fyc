import 'package:equatable/equatable.dart';
import '../../domain/entities/tournament_entity.dart';
import '../../domain/entities/fixture_entity.dart';
import '../../domain/entities/team_entity.dart';

abstract class SportsState extends Equatable {
  const SportsState();
  @override
  List<Object?> get props => [];
}

class SportsInitial extends SportsState {
  const SportsInitial();
}

class SportsLoading extends SportsState {
  const SportsLoading();
}

class SportsLoaded extends SportsState {
  final List<TournamentEntity> tournaments;
  const SportsLoaded(this.tournaments);
  @override
  List<Object?> get props => [tournaments];
}

class SportsDetailLoaded extends SportsState {
  final List<FixtureEntity> fixtures;
  final List<TeamEntity> standings;
  const SportsDetailLoaded({
    required this.fixtures,
    required this.standings,
  });
  @override
  List<Object?> get props => [fixtures, standings];
}

class SportsChallengeSuccess extends SportsState {
  final String message;
  const SportsChallengeSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class SportsFailure extends SportsState {
  final String message;
  const SportsFailure(this.message);
  @override
  List<Object?> get props => [message];
}
