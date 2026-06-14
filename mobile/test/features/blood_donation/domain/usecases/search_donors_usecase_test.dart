import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/features/blood_donation/domain/entities/blood_donor_entity.dart';
import 'package:fyc_connect/features/blood_donation/domain/repositories/blood_donor_repository.dart';
import 'package:fyc_connect/features/blood_donation/domain/usecases/search_donors_usecase.dart';

class MockBloodDonorRepository extends Mock implements BloodDonorRepository {}

void main() {
  late SearchDonorsUseCase useCase;
  late MockBloodDonorRepository repository;

  const tDonors = [
    BloodDonorEntity(id: '1', bloodGroup: 'A+', isAvailable: true),
    BloodDonorEntity(id: '2', bloodGroup: 'A+', isAvailable: true),
  ];

  setUp(() {
    repository = MockBloodDonorRepository();
    useCase = SearchDonorsUseCase(repository);
  });

  test('delegates to repository with correct parameters', () async {
    when(() => repository.searchDonors(
          bloodGroup: any(named: 'bloodGroup'),
          availableOnly: any(named: 'availableOnly'),
        )).thenAnswer((_) async => const Right(tDonors));

    final result = await useCase(bloodGroup: 'A+', availableOnly: true);

    expect(result, const Right(tDonors));
    verify(() => repository.searchDonors(
          bloodGroup: 'A+',
          availableOnly: true,
        )).called(1);
  });

  test('returns all donors when no blood group filter applied', () async {
    when(() => repository.searchDonors(
          bloodGroup: any(named: 'bloodGroup'),
          availableOnly: any(named: 'availableOnly'),
        )).thenAnswer((_) async => const Right(tDonors));

    final result = await useCase();

    expect(result.isRight(), true);
    verify(() => repository.searchDonors(
          bloodGroup: null,
          availableOnly: true,
        )).called(1);
  });

  test('propagates NetworkFailure from repository', () async {
    when(() => repository.searchDonors(
          bloodGroup: any(named: 'bloodGroup'),
          availableOnly: any(named: 'availableOnly'),
        )).thenAnswer((_) async => const Left(NetworkFailure()));

    final result = await useCase(bloodGroup: 'B+');

    result.fold(
      (f) => expect(f, isA<NetworkFailure>()),
      (_) => fail('Expected failure'),
    );
  });
}
