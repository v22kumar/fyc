import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/search_donors_usecase.dart';
import '../../domain/usecases/register_donor_usecase.dart';
import '../../domain/repositories/blood_donor_repository.dart';
import 'blood_donor_event.dart';
import 'blood_donor_state.dart';

class BloodDonorBloc extends Bloc<BloodDonorEvent, BloodDonorState> {
  final SearchDonorsUseCase _searchDonors;
  final RegisterDonorUseCase _registerDonor;
  final BloodDonorRepository _repository;

  BloodDonorBloc({
    required SearchDonorsUseCase searchDonors,
    required RegisterDonorUseCase registerDonor,
    required BloodDonorRepository repository,
  })  : _searchDonors = searchDonors,
        _registerDonor = registerDonor,
        _repository = repository,
        super(const BloodDonorInitial()) {
    on<BloodDonorSearchRequested>(_onSearch);
    on<BloodDonorRegisterRequested>(_onRegister);
    on<BloodDonorContactRequested>(_onContactRequest);
    on<BloodDonorAvailabilityUpdated>(_onAvailabilityUpdate);
  }

  Future<void> _onSearch(
    BloodDonorSearchRequested event,
    Emitter<BloodDonorState> emit,
  ) async {
    emit(const BloodDonorLoading());
    final result = await _searchDonors(
      bloodGroup: event.bloodGroup,
      availableOnly: event.availableOnly,
    );
    result.fold(
      (f) => emit(BloodDonorFailure(f.message)),
      (donors) => emit(BloodDonorSearchSuccess(
        donors: donors,
        activeFilter: event.bloodGroup,
      )),
    );
  }

  Future<void> _onRegister(
    BloodDonorRegisterRequested event,
    Emitter<BloodDonorState> emit,
  ) async {
    emit(const BloodDonorLoading());
    final result = await _registerDonor(
      bloodGroup: event.bloodGroup,
      isAvailable: event.isAvailable,
      lastDonationDate: event.lastDonationDate,
    );
    result.fold(
      (f) => emit(BloodDonorFailure(f.message)),
      (donor) => emit(BloodDonorRegistered(donor)),
    );
  }

  Future<void> _onContactRequest(
    BloodDonorContactRequested event,
    Emitter<BloodDonorState> emit,
  ) async {
    emit(const BloodDonorLoading());
    final result = await _repository.requestContact(event.donorId);
    result.fold(
      (f) => emit(BloodDonorFailure(f.message)),
      (info) => emit(BloodDonorContactRevealed(
        phoneNumber: info['phone_number']!,
        whatsappLink: info['whatsapp_link']!,
      )),
    );
  }

  Future<void> _onAvailabilityUpdate(
    BloodDonorAvailabilityUpdated event,
    Emitter<BloodDonorState> emit,
  ) async {
    emit(const BloodDonorLoading());
    final result = await _repository.updateAvailability(
      donorId: event.donorId,
      isAvailable: event.isAvailable,
    );
    result.fold(
      (f) => emit(BloodDonorFailure(f.message)),
      (donor) => emit(BloodDonorRegistered(donor)),
    );
  }
}
