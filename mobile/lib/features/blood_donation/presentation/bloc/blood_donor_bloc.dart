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
    on<BloodDonorNearbyRequested>(_onNearby);
    on<BloodDonorRegisterRequested>(_onRegister);
    on<BloodDonorContactRequested>(_onContactRequest);
    on<BloodDonorAvailabilityUpdated>(_onAvailabilityUpdate);
  }

  /// Which list request is the current one.
  ///
  /// Bloc runs handlers for *different* event types concurrently, so a search
  /// and a nearby query issued moments apart are genuinely racing — and the one
  /// that emits last wins regardless of which was asked for last.
  ///
  /// That is not a theoretical risk: the hub opens by asking for the plain list
  /// and then, once it has a position, for the ranked one. The ranked reply is
  /// smaller and consistently arrives first, so the plain list overwrote it
  /// every single time and the screen quietly showed no distances at all.
  ///
  /// A sequence number makes it last-*asked* wins, which is what the member
  /// meant by their most recent action.
  int _seq = 0;

  Future<void> _onSearch(
    BloodDonorSearchRequested event,
    Emitter<BloodDonorState> emit,
  ) async {
    final seq = ++_seq;
    emit(const BloodDonorLoading());
    final result = await _searchDonors(
      bloodGroup: event.bloodGroup,
      geographyId: event.geographyId,
      nearby: event.nearby,
      availableOnly: event.availableOnly,
      source: event.source,
    );
    if (seq != _seq) return;
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
      latitude: event.latitude,
      longitude: event.longitude,
      locationConsent: event.locationConsent,
      notifyOptIn: event.notifyOptIn,
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

  Future<void> _onNearby(
    BloodDonorNearbyRequested event,
    Emitter<BloodDonorState> emit,
  ) async {
    final seq = ++_seq;
    emit(const BloodDonorLoading());
    final result = await _repository.donorsNear(
      lat: event.lat,
      lng: event.lng,
      bloodGroup: event.bloodGroup,
    );
    if (seq != _seq) return;
    result.fold(
      (failure) => emit(BloodDonorFailure(failure.message)),
      (donors) => emit(BloodDonorSearchSuccess(donors: donors)),
    );
  }
}
