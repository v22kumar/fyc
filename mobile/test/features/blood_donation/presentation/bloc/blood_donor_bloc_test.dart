import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/features/blood_donation/domain/entities/blood_donor_entity.dart';
import 'package:fyc_connect/features/blood_donation/domain/repositories/blood_donor_repository.dart';
import 'package:fyc_connect/features/blood_donation/domain/usecases/search_donors_usecase.dart';
import 'package:fyc_connect/features/blood_donation/domain/usecases/register_donor_usecase.dart';
import 'package:fyc_connect/features/blood_donation/presentation/bloc/blood_donor_bloc.dart';
import 'package:fyc_connect/features/blood_donation/presentation/bloc/blood_donor_event.dart';
import 'package:fyc_connect/features/blood_donation/presentation/bloc/blood_donor_state.dart';

class MockSearchDonorsUseCase extends Mock implements SearchDonorsUseCase {}
class MockRegisterDonorUseCase extends Mock implements RegisterDonorUseCase {}
class MockBloodDonorRepository extends Mock implements BloodDonorRepository {}

const _tDonor = BloodDonorEntity(
  id: 'donor-1',
  bloodGroup: 'O+',
  isAvailable: true,
  fullNameEn: 'Test Donor',
);

void main() {
  late BloodDonorBloc bloc;
  late MockSearchDonorsUseCase searchDonors;
  late MockRegisterDonorUseCase registerDonor;
  late MockBloodDonorRepository repository;

  setUp(() {
    searchDonors = MockSearchDonorsUseCase();
    registerDonor = MockRegisterDonorUseCase();
    repository = MockBloodDonorRepository();

    bloc = BloodDonorBloc(
      searchDonors: searchDonors,
      registerDonor: registerDonor,
      repository: repository,
    );
  });

  tearDown(() => bloc.close());

  test('initial state is BloodDonorInitial', () {
    expect(bloc.state, const BloodDonorInitial());
  });

  group('BloodDonorSearchRequested', () {
    blocTest<BloodDonorBloc, BloodDonorState>(
      'emits [Loading, SearchSuccess] on success',
      build: () {
        when(() => searchDonors(
              bloodGroup: any(named: 'bloodGroup'),
              availableOnly: any(named: 'availableOnly'),
            )).thenAnswer((_) async => const Right([_tDonor]));
        return bloc;
      },
      act: (b) =>
          b.add(const BloodDonorSearchRequested(bloodGroup: 'O+')),
      expect: () => [
        const BloodDonorLoading(),
        const BloodDonorSearchSuccess(donors: [_tDonor], activeFilter: 'O+'),
      ],
    );

    blocTest<BloodDonorBloc, BloodDonorState>(
      'emits [Loading, Failure] on error',
      build: () {
        when(() => searchDonors(
              bloodGroup: any(named: 'bloodGroup'),
              availableOnly: any(named: 'availableOnly'),
            )).thenAnswer(
          (_) async => const Left(NetworkFailure()),
        );
        return bloc;
      },
      act: (b) => b.add(const BloodDonorSearchRequested()),
      expect: () => [
        const BloodDonorLoading(),
        const BloodDonorFailure(
          "We couldn't reach the network. Please check your internet connection.",
        ),
      ],
    );

    blocTest<BloodDonorBloc, BloodDonorState>(
      'emits SearchSuccess with empty list when no donors found',
      build: () {
        when(() => searchDonors(
              bloodGroup: any(named: 'bloodGroup'),
              availableOnly: any(named: 'availableOnly'),
            )).thenAnswer((_) async => const Right([]));
        return bloc;
      },
      act: (b) => b.add(const BloodDonorSearchRequested(bloodGroup: 'AB-')),
      expect: () => [
        const BloodDonorLoading(),
        const BloodDonorSearchSuccess(donors: [], activeFilter: 'AB-'),
      ],
    );
  });

  group('BloodDonorRegisterRequested', () {
    blocTest<BloodDonorBloc, BloodDonorState>(
      'emits [Loading, Registered] on success',
      build: () {
        when(() => registerDonor(
              bloodGroup: any(named: 'bloodGroup'),
              isAvailable: any(named: 'isAvailable'),
              lastDonationDate: any(named: 'lastDonationDate'),
            )).thenAnswer((_) async => const Right(_tDonor));
        return bloc;
      },
      act: (b) => b.add(
        const BloodDonorRegisterRequested(
          bloodGroup: 'O+',
          isAvailable: true,
        ),
      ),
      expect: () => [
        const BloodDonorLoading(),
        const BloodDonorRegistered(_tDonor),
      ],
    );

    blocTest<BloodDonorBloc, BloodDonorState>(
      'emits [Loading, Failure] when registration fails',
      build: () {
        when(() => registerDonor(
              bloodGroup: any(named: 'bloodGroup'),
              isAvailable: any(named: 'isAvailable'),
              lastDonationDate: any(named: 'lastDonationDate'),
            )).thenAnswer(
          (_) async => const Left(AuthFailure('Unauthorized')),
        );
        return bloc;
      },
      act: (b) => b.add(
        const BloodDonorRegisterRequested(bloodGroup: 'A+'),
      ),
      expect: () => [
        const BloodDonorLoading(),
        const BloodDonorFailure('Unauthorized'),
      ],
    );
  });

  group('BloodDonorContactRequested', () {
    blocTest<BloodDonorBloc, BloodDonorState>(
      'emits [Loading, ContactRevealed] on success',
      build: () {
        when(() => repository.requestContact(any())).thenAnswer(
          (_) async => const Right({
            'phone_number': '+919876543210',
            'whatsapp_link': 'https://wa.me/919876543210',
          }),
        );
        return bloc;
      },
      act: (b) => b.add(const BloodDonorContactRequested('donor-1')),
      expect: () => [
        const BloodDonorLoading(),
        const BloodDonorContactRevealed(
          phoneNumber: '+919876543210',
          whatsappLink: 'https://wa.me/919876543210',
        ),
      ],
    );
  });

  group('BloodDonorAvailabilityUpdated', () {
    blocTest<BloodDonorBloc, BloodDonorState>(
      'emits [Loading, Registered] after availability toggle',
      build: () {
        when(() => repository.updateAvailability(
              donorId: any(named: 'donorId'),
              isAvailable: any(named: 'isAvailable'),
            )).thenAnswer((_) async => const Right(_tDonor));
        return bloc;
      },
      act: (b) => b.add(const BloodDonorAvailabilityUpdated(
        donorId: 'donor-1',
        isAvailable: false,
      )),
      expect: () => [
        const BloodDonorLoading(),
        const BloodDonorRegistered(_tDonor),
      ],
    );
  });
}
