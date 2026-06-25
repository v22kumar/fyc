import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/player_entity.dart';
import '../../domain/repositories/sports_repository.dart';

abstract class TeamManagementState extends Equatable {
  const TeamManagementState();
  @override
  List<Object?> get props => [];
}

class TeamManagementInitial extends TeamManagementState {}
class TeamManagementLoading extends TeamManagementState {}
class TeamManagementLoaded extends TeamManagementState {
  final List<PlayerEntity> players;
  const TeamManagementLoaded(this.players);
  @override
  List<Object?> get props => [players];
}
class TeamManagementFailure extends TeamManagementState {
  final String message;
  const TeamManagementFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class TeamManagementCubit extends Cubit<TeamManagementState> {
  final SportsRepository _repository;
  final String teamId;

  TeamManagementCubit(this._repository, this.teamId) : super(TeamManagementInitial());

  Future<void> fetchPlayers() async {
    emit(TeamManagementLoading());
    final result = await _repository.fetchTeamPlayers(teamId);
    result.fold(
      (failure) => emit(TeamManagementFailure(failure.message)),
      (players) => emit(TeamManagementLoaded(players)),
    );
  }

  Future<void> registerPlayer(Map<String, dynamic> data) async {
    final currentState = state;
    emit(TeamManagementLoading());
    final result = await _repository.registerPlayer(teamId, data);
    result.fold(
      (failure) {
        emit(TeamManagementFailure(failure.message));
        if (currentState is TeamManagementLoaded) {
          emit(currentState);
        }
      },
      (player) {
        if (currentState is TeamManagementLoaded) {
          emit(TeamManagementLoaded([...currentState.players, player]));
        } else {
          emit(TeamManagementLoaded([player]));
        }
      },
    );
  }
}
