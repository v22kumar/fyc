import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_drives_usecase.dart';
import '../../domain/usecases/register_tree_usecase.dart';
import '../../domain/repositories/green_repository.dart';
import 'green_event.dart';
import 'green_state.dart';

class GreenBloc extends Bloc<GreenEvent, GreenState> {
  final FetchDrivesUseCase _fetchDrives;
  final RegisterTreeUseCase _registerTree;
  final GreenRepository _repository;

  GreenBloc({
    required FetchDrivesUseCase fetchDrives,
    required RegisterTreeUseCase registerTree,
    required GreenRepository repository,
  })  : _fetchDrives = fetchDrives,
        _registerTree = registerTree,
        _repository = repository,
        super(const GreenInitial()) {
    on<GreenFetchRequested>(_onFetch);
    on<GreenTreesRequested>(_onTrees);
    on<GreenTreeRegistered>(_onRegister);
  }

  Future<void> _onFetch(
    GreenFetchRequested event,
    Emitter<GreenState> emit,
  ) async {
    emit(const GreenLoading());
    final statsResult = await _repository.fetchStats();
    final statsFailure = statsResult.fold((f) => f, (_) => null);
    if (statsFailure != null) {
      emit(GreenFailure(statsFailure.message));
      return;
    }
    final drivesResult = await _fetchDrives();
    drivesResult.fold(
      (f) => emit(GreenFailure(f.message)),
      (drives) => emit(GreenLoaded(
        stats: statsResult.getOrElse(() => throw StateError('unreachable')),
        drives: drives,
      )),
    );
  }

  Future<void> _onTrees(
    GreenTreesRequested event,
    Emitter<GreenState> emit,
  ) async {
    emit(const GreenLoading());
    final result = await _repository.fetchTrees(driveId: event.driveId);
    result.fold(
      (f) => emit(GreenFailure(f.message)),
      (trees) => emit(GreenTreesLoaded(trees)),
    );
  }

  Future<void> _onRegister(
    GreenTreeRegistered event,
    Emitter<GreenState> emit,
  ) async {
    emit(const GreenLoading());

    String? photoUrl;
    if (event.photoFilePath != null) {
      final uploadResult = await _repository.uploadPhoto(event.photoFilePath!);
      final uploadFailure = uploadResult.fold((f) => f, (_) => null);
      if (uploadFailure != null) {
        emit(GreenFailure(uploadFailure.message));
        return;
      }
      photoUrl = uploadResult.getOrElse(() => '');
    }

    final result = await _registerTree(
      driveId: event.driveId,
      speciesTa: event.speciesTa,
      speciesEn: event.speciesEn,
      latitude: event.latitude,
      longitude: event.longitude,
      plantedDate: event.plantedDate,
      photoUrl: photoUrl,
      notes: event.notes,
    );
    result.fold(
      (f) => emit(GreenFailure(f.message)),
      (tree) => emit(GreenTreeRegisteredSuccess(tree)),
    );
  }
}
