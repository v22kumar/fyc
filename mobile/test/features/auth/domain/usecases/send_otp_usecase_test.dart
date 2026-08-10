import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:fyc_connect/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:fyc_connect/features/auth/domain/entities/otp_challenge.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late SendOtpUseCase useCase;
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    useCase = SendOtpUseCase(repository);
  });

  // Note what this cannot see: it mocks the repository, so the hop where the
  // server's answer is actually read never runs. That is precisely where the
  // handle was being replaced by the literal text `$id`, and why every test
  // here passed while no member could sign in. See
  // test/features/auth/send_otp_datasource_test.dart.
  test('returns the challenge on success', () async {
    when(() => repository.sendOtp(
          organizationId: any(named: 'organizationId'),
          phoneNumber: any(named: 'phoneNumber'),
        )).thenAnswer(
            (_) async => const Right(OtpChallenge(id: 'vid-abc', channel: 'sms')));

    final result = await useCase(
      organizationId: 'org-1',
      phoneNumber: '+919876543210',
    );

    expect(result, const Right(OtpChallenge(id: 'vid-abc', channel: 'sms')));
    verify(() => repository.sendOtp(
          organizationId: 'org-1',
          phoneNumber: '+919876543210',
        )).called(1);
  });

  test('returns ValidationFailure for empty phone number', () async {
    final result = await useCase(
      organizationId: 'org-1',
      phoneNumber: '   ',
    );

    result.fold(
      (f) => expect(f, isA<ValidationFailure>()),
      (_) => fail('Expected failure'),
    );
    verifyNever(() => repository.sendOtp(
          organizationId: any(named: 'organizationId'),
          phoneNumber: any(named: 'phoneNumber'),
        ));
  });

  test('propagates ServerFailure from repository', () async {
    when(() => repository.sendOtp(
          organizationId: any(named: 'organizationId'),
          phoneNumber: any(named: 'phoneNumber'),
        )).thenAnswer(
      (_) async => const Left(ServerFailure('Server down')),
    );

    final result = await useCase(
      organizationId: 'org-1',
      phoneNumber: '+919876543210',
    );

    result.fold(
      (f) {
        expect(f, isA<ServerFailure>());
        expect(f.message, 'Server down');
      },
      (_) => fail('Expected failure'),
    );
  });
}
