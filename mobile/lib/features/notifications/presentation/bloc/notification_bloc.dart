import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/notification_entity.dart';
import '../../data/repositories/notification_repository.dart';

// Events
abstract class NotificationEvent {}
class FetchNotifications extends NotificationEvent {}
class MarkNotificationAsRead extends NotificationEvent {
  final String id;
  MarkNotificationAsRead(this.id);
}
class MarkAllNotificationsAsRead extends NotificationEvent {}
class TrackNotificationClick extends NotificationEvent {
  final String id;
  TrackNotificationClick(this.id);
}

// States
abstract class NotificationState {}
class NotificationInitial extends NotificationState {}
class NotificationLoading extends NotificationState {}
class NotificationLoaded extends NotificationState {
  final List<NotificationEntity> notifications;
  NotificationLoaded(this.notifications);
}
class NotificationError extends NotificationState {
  final String message;
  NotificationError(this.message);
}

// BLoC
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository repository;

  NotificationBloc({required this.repository}) : super(NotificationInitial()) {
    on<FetchNotifications>(_onFetchNotifications);
    on<MarkNotificationAsRead>(_onMarkAsRead);
    on<MarkAllNotificationsAsRead>(_onMarkAllAsRead);
    on<TrackNotificationClick>(_onTrackClick);
  }

  Future<void> _onFetchNotifications(FetchNotifications event, Emitter<NotificationState> emit) async {
    emit(NotificationLoading());
    final result = await repository.getNotifications();
    result.fold(
      (failure) => emit(NotificationError(failure.message)),
      (notifications) => emit(NotificationLoaded(notifications)),
    );
  }

  Future<void> _onTrackClick(TrackNotificationClick event, Emitter<NotificationState> emit) async {
    await repository.trackClick(event.id);
  }

  Future<void> _onMarkAsRead(MarkNotificationAsRead event, Emitter<NotificationState> emit) async {
    final currentState = state;
    if (currentState is NotificationLoaded) {
      final updatedList = currentState.notifications.map((n) {
        if (n.id == event.id) {
          return NotificationEntity(
            id: n.id,
            titleEn: n.titleEn,
            titleTa: n.titleTa,
            bodyEn: n.bodyEn,
            bodyTa: n.bodyTa,
            notificationType: n.notificationType,
            isRead: true,
            createdAt: n.createdAt,
            data: n.data,
          );
        }
        return n;
      }).toList();
      emit(NotificationLoaded(updatedList)); // Optimistic UI update
      await repository.markAsRead(event.id);
    }
  }

  Future<void> _onMarkAllAsRead(MarkAllNotificationsAsRead event, Emitter<NotificationState> emit) async {
    final currentState = state;
    if (currentState is NotificationLoaded) {
      final updatedList = currentState.notifications.map((n) {
        return NotificationEntity(
          id: n.id,
          titleEn: n.titleEn,
          titleTa: n.titleTa,
          bodyEn: n.bodyEn,
          bodyTa: n.bodyTa,
          notificationType: n.notificationType,
          isRead: true,
          createdAt: n.createdAt,
          data: n.data,
        );
      }).toList();
      emit(NotificationLoaded(updatedList)); // Optimistic UI update
      await repository.markAllAsRead();
    }
  }
}
