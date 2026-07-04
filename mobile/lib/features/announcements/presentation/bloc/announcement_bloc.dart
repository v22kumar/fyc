import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/announcement_entity.dart';
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
    await emit.forEach(
      _fetchAnnouncements(category: event.category),
      onData: (Either<Failure, List<AnnouncementEntity>> result) {
        return result.fold(
          (f) => AnnouncementFailure(f.message),
          (announcements) {
            final sorted = [...announcements]..sort((a, b) {
                if (a.isPinned != b.isPinned) {
                  return a.isPinned ? -1 : 1;
                }
                return b.createdAt.compareTo(a.createdAt);
              });
            return AnnouncementLoaded(sorted);
          },
        );
      },
      onError: (_, __) => const AnnouncementFailure('Unknown error'),
    );
  }
}
