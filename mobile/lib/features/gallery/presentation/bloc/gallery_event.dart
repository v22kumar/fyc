import 'package:equatable/equatable.dart';

abstract class GalleryEvent extends Equatable {
  const GalleryEvent();
  @override
  List<Object?> get props => [];
}

class GalleryFetchRequested extends GalleryEvent {
  const GalleryFetchRequested();
}

class GalleryEventPhotosRequested extends GalleryEvent {
  final String eventId;
  const GalleryEventPhotosRequested(this.eventId);
  @override
  List<Object?> get props => [eventId];
}
