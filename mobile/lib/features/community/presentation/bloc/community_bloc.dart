import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_profiles_usecase.dart';
import 'community_event.dart';
import 'community_state.dart';

class CommunityBloc extends Bloc<CommunityEvent, CommunityState> {
  final FetchProfilesUseCase _fetchProfiles;

  CommunityBloc({required FetchProfilesUseCase fetchProfiles})
      : _fetchProfiles = fetchProfiles,
        super(const CommunityInitial()) {
    on<CommunityFetchRequested>(_onFetch);
  }

  Future<void> _onFetch(
    CommunityFetchRequested event,
    Emitter<CommunityState> emit,
  ) async {
    emit(const CommunityLoading());
    final result = await _fetchProfiles();
    result.fold(
      (f) => emit(CommunityFailure(f.message)),
      (profiles) => emit(CommunityLoaded(profiles)),
    );
  }
}
