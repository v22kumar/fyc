import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/journey_entity.dart';
import '../../domain/usecases/fetch_journey_usecase.dart';

// Events
abstract class JourneyEvent extends Equatable {
  const JourneyEvent();
  @override
  List<Object?> get props => [];
}

class JourneyFetchRequested extends JourneyEvent {
  const JourneyFetchRequested();
}

// States
abstract class JourneyState extends Equatable {
  const JourneyState();
  @override
  List<Object?> get props => [];
}

class JourneyInitial extends JourneyState {}

class JourneyLoading extends JourneyState {}

class JourneyLoaded extends JourneyState {
  final JourneyEntity journey;
  const JourneyLoaded(this.journey);
  @override
  List<Object?> get props => [journey];
}

class JourneyFailure extends JourneyState {
  final String message;
  const JourneyFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class JourneyBloc extends Bloc<JourneyEvent, JourneyState> {
  final FetchJourneyUseCase _fetchJourney;

  JourneyBloc({required FetchJourneyUseCase fetchJourney})
      : _fetchJourney = fetchJourney,
        super(JourneyInitial()) {
    on<JourneyFetchRequested>(_onFetch);
  }

  Future<void> _onFetch(
    JourneyFetchRequested event,
    Emitter<JourneyState> emit,
  ) async {
    emit(JourneyLoading());
    final result = await _fetchJourney();
    result.fold(
      (f) => emit(JourneyFailure(f.message)),
      (journey) => emit(JourneyLoaded(journey)),
    );
  }
}
