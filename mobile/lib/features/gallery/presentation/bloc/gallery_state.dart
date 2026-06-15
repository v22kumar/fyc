import 'package:equatable/equatable.dart';
import '../../domain/entities/photo_entity.dart';

abstract class GalleryState extends Equatable {
  const GalleryState();
  @override
  List<Object?> get props => [];
}

class GalleryInitial extends GalleryState {
  const GalleryInitial();
}

class GalleryLoading extends GalleryState {
  const GalleryLoading();
}

class GalleryLoaded extends GalleryState {
  final List<PhotoEntity> photos;
  const GalleryLoaded(this.photos);
  @override
  List<Object?> get props => [photos];
}

class GalleryFailure extends GalleryState {
  final String message;
  const GalleryFailure(this.message);
  @override
  List<Object?> get props => [message];
}
