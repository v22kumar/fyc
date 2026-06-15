import 'package:equatable/equatable.dart';
import '../../domain/entities/event_entity.dart';

abstract class EventState extends Equatable {
  const EventState();
  @override
  List<Object?> get props => [];
}

class EventInitial extends EventState {
  const EventInitial();
}

class EventLoading extends EventState {
  const EventLoading();
}

class EventLoaded extends EventState {
  final List<EventEntity> events;
  const EventLoaded(this.events);
  @override
  List<Object?> get props => [events];
}

class EventCheckinSuccess extends EventState {
  final String message;
  const EventCheckinSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class EventFailure extends EventState {
  final String message;
  const EventFailure(this.message);
  @override
  List<Object?> get props => [message];
}
