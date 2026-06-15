import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_photos_usecase.dart';
import '../../domain/repositories/gallery_repository.dart';
import 'gallery_event.dart';
import 'gallery_state.dart';

class GalleryBloc extends Bloc<GalleryEvent, GalleryState> {
  final FetchPhotosUseCase _fetchPhotos;
  final GalleryRepository _repository;

  GalleryBloc({
    required FetchPhotosUseCase fetchPhotos,
    required GalleryRepository repository,
  })  : _fetchPhotos = fetchPhotos,
        _repository = repository,
        super(const GalleryInitial()) {
    on<GalleryFetchRequested>(_onFetch);
    on<GalleryEventPhotosRequested>(_onFetchEventPhotos);
  }

  Future<void> _onFetch(
    GalleryFetchRequested event,
    Emitter<GalleryState> emit,
  ) async {
    emit(const GalleryLoading());
    final result = await _fetchPhotos();
    result.fold(
      (f) => emit(GalleryFailure(f.message)),
      (photos) => emit(GalleryLoaded(photos)),
    );
  }

  Future<void> _onFetchEventPhotos(
    GalleryEventPhotosRequested event,
    Emitter<GalleryState> emit,
  ) async {
    emit(const GalleryLoading());
    final result = await _repository.fetchEventPhotos(event.eventId);
    result.fold(
      (f) => emit(GalleryFailure(f.message)),
      (photos) => emit(GalleryLoaded(photos)),
    );
  }
}
