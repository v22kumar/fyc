import 'package:equatable/equatable.dart';

abstract class EventEvent extends Equatable {
  const EventEvent();
  @override
  List<Object?> get props => [];
}

class EventFetchRequested extends EventEvent {
  const EventFetchRequested();
}

class EventCheckinRequested extends EventEvent {
  final String eventId;
  const EventCheckinRequested(this.eventId);
  @override
  List<Object?> get props => [eventId];
}

class EventDeleteRequested extends EventEvent {
  final String eventId;
  const EventDeleteRequested(this.eventId);
  @override
  List<Object?> get props => [eventId];
}
