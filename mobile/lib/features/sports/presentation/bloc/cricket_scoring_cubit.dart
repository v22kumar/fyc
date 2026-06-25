import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cricket_match_state_entity.dart';
import '../../domain/repositories/sports_repository.dart';

abstract class CricketScoringState extends Equatable {
  const CricketScoringState();
  @override
  List<Object?> get props => [];
}

class CricketScoringInitial extends CricketScoringState {}
class CricketScoringLoading extends CricketScoringState {}
class CricketScoringLoaded extends CricketScoringState {
  final CricketMatchStateEntity matchState;
  const CricketScoringLoaded(this.matchState);
  @override
  List<Object?> get props => [matchState];
}
class CricketScoringFailure extends CricketScoringState {
  final String message;
  const CricketScoringFailure(this.message);
  @override
  List<Object?> get props => [message];
}

class CricketScoringCubit extends Cubit<CricketScoringState> {
  final SportsRepository _repository;
  final String fixtureId;

  CricketScoringCubit(this._repository, this.fixtureId) : super(CricketScoringInitial());

  Future<void> fetchMatchState() async {
    emit(CricketScoringLoading());
    final result = await _repository.fetchCricketMatchState(fixtureId);
    result.fold(
      (failure) => emit(CricketScoringFailure(failure.message)),
      (matchState) => emit(CricketScoringLoaded(matchState)),
    );
  }

  Future<void> scoreBall(Map<String, dynamic> data) async {
    emit(CricketScoringLoading());
    final result = await _repository.scoreCricketBall(fixtureId, data);
    result.fold(
      (failure) => emit(CricketScoringFailure(failure.message)),
      (matchState) => emit(CricketScoringLoaded(matchState)),
    );
  }

  Future<void> undoBall() async {
    emit(CricketScoringLoading());
    final result = await _repository.undoCricketBall(fixtureId);
    result.fold(
      (failure) => emit(CricketScoringFailure(failure.message)),
      (matchState) => emit(CricketScoringLoaded(matchState)),
    );
  }
}
