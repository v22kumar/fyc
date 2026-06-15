import 'package:equatable/equatable.dart';
import '../../domain/entities/announcement_entity.dart';

abstract class AnnouncementState extends Equatable {
  const AnnouncementState();
  @override
  List<Object?> get props => [];
}

class AnnouncementInitial extends AnnouncementState {
  const AnnouncementInitial();
}

class AnnouncementLoading extends AnnouncementState {
  const AnnouncementLoading();
}

class AnnouncementLoaded extends AnnouncementState {
  final List<AnnouncementEntity> announcements;
  const AnnouncementLoaded(this.announcements);
  @override
  List<Object?> get props => [announcements];
}

class AnnouncementFailure extends AnnouncementState {
  final String message;
  const AnnouncementFailure(this.message);
  @override
  List<Object?> get props => [message];
}
