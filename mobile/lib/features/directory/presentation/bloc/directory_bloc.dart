import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_contacts_usecase.dart';
import 'directory_event.dart';
import 'directory_state.dart';

class DirectoryBloc extends Bloc<DirectoryEvent, DirectoryState> {
  final FetchContactsUseCase _fetchContacts;

  DirectoryBloc({
    required FetchContactsUseCase fetchContacts,
  })  : _fetchContacts = fetchContacts,
        super(const DirectoryInitial()) {
    on<DirectoryFetchRequested>(_onFetch);
  }

  Future<void> _onFetch(
    DirectoryFetchRequested event,
    Emitter<DirectoryState> emit,
  ) async {
    emit(const DirectoryLoading());
    final result = await _fetchContacts(category: event.category);
    result.fold(
      (f) => emit(DirectoryFailure(f.message)),
      (contacts) => emit(DirectoryLoaded(contacts)),
    );
  }
}
