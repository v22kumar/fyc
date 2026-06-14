import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/features/auth/domain/entities/user_entity.dart';
import 'package:fyc_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:fyc_connect/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/register_user_usecase.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_event.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_state.dart';

class MockSendOtpUseCase extends Mock implements SendOtpUseCase {}
class MockVerifyOtpUseCase extends Mock implements VerifyOtpUseCase {}
class MockRegisterUserUseCase extends Mock implements RegisterUserUseCase {}
class MockAuthRepository extends Mock implements AuthRepository {}
class MockLocalStorage extends Mock implements LocalStorage {}

const _tUser = UserEntity(
  id: 'user-1',
  phoneNumber: '+919876543210',
  role: 'CITIZEN',
  isVerified: true,
  preferredLanguage: 'ta',
);

void main() {
  late AuthBloc bloc;
  late MockSendOtpUseCase sendOtp;
  late MockVerifyOtpUseCase verifyOtp;
  late MockRegisterUserUseCase registerUser;
  late MockAuthRepository repository;
  late MockLocalStorage storage;

  setUp(() {
    sendOtp = MockSendOtpUseCase();
    verifyOtp = MockVerifyOtpUseCase();
    registerUser = MockRegisterUserUseCase();
    repository = MockAuthRepository();
    storage = MockLocalStorage();

    when(() => storage.isLoggedIn).thenReturn(false);

    bloc = AuthBloc(
      sendOtp: sendOtp,
      verifyOtp: verifyOtp,
      registerUser: registerUser,
      repository: repository,
      storage: storage,
    );
  });

  tearDown(() => bloc.close());

  test('initial state is AuthInitial', () {
    expect(bloc.state, const AuthInitial());
  });

  group('AuthCheckRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthUnauthenticated] when not logged in',
      build: () {
        when(() => storage.isLoggedIn).thenReturn(false);
        return bloc;
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [const AuthUnauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Authenticated] when token valid',
      build: () {
        when(() => storage.isLoggedIn).thenReturn(true);
        when(() => repository.getMe())
            .thenAnswer((_) async => const Right(_tUser));
        return bloc;
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [const AuthLoading(), AuthAuthenticated(_tUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Unauthenticated] when token expired',
      build: () {
        when(() => storage.isLoggedIn).thenReturn(true);
        when(() => repository.getMe()).thenAnswer(
          (_) async => const Left(AuthFailure('Token expired')),
        );
        return bloc;
      },
      act: (b) => b.add(const AuthCheckRequested()),
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
    );
  });

  group('AuthSendOtpRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Loading, OtpSent] on success',
      build: () {
        when(() => sendOtp(
              organizationId: any(named: 'organizationId'),
              phoneNumber: any(named: 'phoneNumber'),
            )).thenAnswer((_) async => const Right('vid-123'));
        return bloc;
      },
      act: (b) => b.add(const AuthSendOtpRequested(
        organizationId: 'org-1',
        phoneNumber: '+919876543210',
      )),
      expect: () => [
        const AuthLoading(),
        const AuthOtpSent(
          verificationId: 'vid-123',
          phoneNumber: '+919876543210',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, AuthFailureState] on error',
      build: () {
        when(() => sendOtp(
              organizationId: any(named: 'organizationId'),
              phoneNumber: any(named: 'phoneNumber'),
            )).thenAnswer((_) async => const Left(ServerFailure('Bad request')));
        return bloc;
      },
      act: (b) => b.add(const AuthSendOtpRequested(
        organizationId: 'org-1',
        phoneNumber: '+919876543210',
      )),
      expect: () => [
        const AuthLoading(),
        const AuthFailureState('Bad request'),
      ],
    );
  });

  group('AuthVerifyOtpRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Authenticated] on valid OTP',
      build: () {
        when(() => verifyOtp(
              verificationId: any(named: 'verificationId'),
              otpCode: any(named: 'otpCode'),
            )).thenAnswer((_) async => const Right(_tUser));
        return bloc;
      },
      act: (b) => b.add(const AuthVerifyOtpRequested(
        verificationId: 'vid-123',
        otpCode: '654321',
      )),
      expect: () => [const AuthLoading(), AuthAuthenticated(_tUser)],
    );
  });

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Unauthenticated] after logout',
      build: () {
        when(() => repository.logout()).thenAnswer((_) async {});
        return bloc;
      },
      act: (b) => b.add(const AuthLogoutRequested()),
      expect: () => [const AuthUnauthenticated()],
    );
  });
}
