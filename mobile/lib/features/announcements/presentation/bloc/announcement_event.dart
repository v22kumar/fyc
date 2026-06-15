import 'package:equatable/equatable.dart';

abstract class AnnouncementEvent extends Equatable {
  const AnnouncementEvent();
  @override
  List<Object?> get props => [];
}

class AnnouncementFetchRequested extends AnnouncementEvent {
  final String? category;
  const AnnouncementFetchRequested({this.category});
  @override
  List<Object?> get props => [category];
}
