import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_announcements_usecase.dart';
import 'announcement_event.dart';
import 'announcement_state.dart';

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final FetchAnnouncementsUseCase _fetchAnnouncements;

  AnnouncementBloc({
    required FetchAnnouncementsUseCase fetchAnnouncements,
  })  : _fetchAnnouncements = fetchAnnouncements,
        super(const AnnouncementInitial()) {
    on<AnnouncementFetchRequested>(_onFetch);
  }

  Future<void> _onFetch(
    AnnouncementFetchRequested event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(const AnnouncementLoading());
    final result = await _fetchAnnouncements(category: event.category);
    result.fold(
      (f) => emit(AnnouncementFailure(f.message)),
      (announcements) {
        final sorted = [...announcements]..sort((a, b) {
            if (a.isPinned != b.isPinned) {
              return a.isPinned ? -1 : 1;
            }
            return b.createdAt.compareTo(a.createdAt);
          });
        emit(AnnouncementLoaded(sorted));
      },
    );
  }
}
