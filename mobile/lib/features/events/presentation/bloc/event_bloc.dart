import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_events_usecase.dart';
import '../../domain/repositories/event_repository.dart';
import 'event_event.dart';
import 'event_state.dart';

class EventBloc extends Bloc<EventEvent, EventState> {
  final FetchEventsUseCase _fetchEvents;
  final EventRepository _repository;

  EventBloc({
    required FetchEventsUseCase fetchEvents,
    required EventRepository repository,
  })  : _fetchEvents = fetchEvents,
        _repository = repository,
        super(const EventInitial()) {
    on<EventFetchRequested>(_onFetch);
    on<EventCheckinRequested>(_onCheckin);
  }

  Future<void> _onFetch(
    EventFetchRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    final result = await _fetchEvents();
    result.fold(
      (f) => emit(EventFailure(f.message)),
      (events) => emit(EventLoaded(events)),
    );
  }

  Future<void> _onCheckin(
    EventCheckinRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    final result = await _repository.checkinEvent(event.eventId);
    result.fold(
      (f) => emit(EventFailure(f.message)),
      (msg) => emit(EventCheckinSuccess(msg)),
    );
  }
}
