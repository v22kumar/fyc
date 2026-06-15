import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/fetch_certificate_usecase.dart';
import 'volunteer_cert_event.dart';
import 'volunteer_cert_state.dart';

class VolunteerCertBloc extends Bloc<VolunteerCertEvent, VolunteerCertState> {
  final FetchCertificateUseCase _fetchCertificate;

  VolunteerCertBloc({required FetchCertificateUseCase fetchCertificate})
      : _fetchCertificate = fetchCertificate,
        super(const VolunteerCertInitial()) {
    on<VolunteerCertFetchRequested>(_onFetch);
  }

  Future<void> _onFetch(
    VolunteerCertFetchRequested event,
    Emitter<VolunteerCertState> emit,
  ) async {
    emit(const VolunteerCertLoading());
    final result = await _fetchCertificate();
    result.fold(
      (f) => emit(VolunteerCertFailure(f.message)),
      (bytes) => emit(VolunteerCertLoaded(bytes)),
    );
  }
}
