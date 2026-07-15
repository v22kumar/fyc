import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/event_entity.dart';
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
    on<EventDeleteRequested>(_onDelete);
  }

  Future<void> _onFetch(
    EventFetchRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    await emit.forEach(
      _fetchEvents(),
      onData: (Either<Failure, List<EventEntity>> result) {
        return result.fold(
          (f) => EventFailure(f.message),
          (events) => EventLoaded(events),
        );
      },
      onError: (_, __) => const EventFailure('Unknown error'),
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

  Future<void> _onDelete(
    EventDeleteRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    final result = await _repository.deleteEvent(event.eventId);
    result.fold(
      (f) => emit(EventFailure(f.message)),
      (msg) {
        emit(EventDeleteSuccess(msg));
        add(const EventFetchRequested());
      },
    );
  }
}
