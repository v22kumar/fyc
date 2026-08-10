import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/features/auth/data/models/user_model.dart';
import 'package:fyc_connect/features/auth/domain/entities/user_entity.dart';
import 'package:fyc_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:fyc_connect/features/auth/domain/usecases/register_user_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_event.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_state.dart';

/// The app opening without knowing whose it is.
///
/// Home draws the member's name and initial straight off [AuthState]. Any
/// failure of `GET /me` used to emit [AuthUnauthenticated], so a dropped
/// request on a cold start rendered "Good Morning" with nothing after it and
/// a `?` in the avatar — for somebody signed in for months, with valid tokens
/// sitting in storage.
class _Repo implements AuthRepository {
  _Repo(this.result);

  Either<Failure, UserEntity> result;
  int calls = 0;

  @override
  Future<Either<Failure, UserEntity>> getMe() async {
    calls++;
    return result;
  }

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('not used by these tests');
}

const _arun = UserModel(
  id: 'u1',
  phoneNumber: '+919000000001',
  role: 'USER',
  isVerified: true,
  preferredLanguage: 'ta',
  fullNameEn: 'Arun Kumar',
  fullNameTa: 'அருண் குமார்',
);

/// The bloc needs its OTP use-cases to exist; these tests never fire them.
AuthBloc _bloc(_Repo repo, LocalStorage storage) => AuthBloc(
      sendOtp: SendOtpUseCase(repo),
      verifyOtp: VerifyOtpUseCase(repo),
      registerUser: RegisterUserUseCase(repo),
      repository: repo,
      storage: storage,
    );

/// A genuinely signed-in member has BOTH the marker and a token.
///
/// These fixtures used to set only the marker — the same assumption that let
/// Android auto-backup restore a "session" onto a fresh install with no token
/// and open the app as nobody. The token is seeded in the legacy plaintext
/// slot because the Keystore has no platform channel under `flutter test`;
/// getToken() migrates it, which is the path a real upgrade takes anyway.
Future<LocalStorage> _storageWith({
  required bool signedIn,
  bool withToken = true,
  Map<String, Object>? extra,
}) async {
  SharedPreferences.setMockInitialValues({
    if (signedIn) 'fyc_has_session': true,
    if (signedIn && withToken) 'fyc_auth_token': 'a-real-token',
    ...?extra,
  });
  return LocalStorage(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a signed-in member is greeted before the network answers', () async {
    final storage = await _storageWith(signedIn: true);
    await storage.saveCachedUser(_arun.toJson());

    final bloc = _bloc(_Repo(const Right(_arun)), storage);
    addTearDown(bloc.close);

    final states = <AuthState>[];
    bloc.stream.listen(states.add);

    bloc.add(const AuthCheckRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(states.first, isA<AuthAuthenticated>(),
        reason: 'the cached profile arrives before any request completes');
    expect((states.first as AuthAuthenticated).user.fullNameEn, 'Arun Kumar');
  });

  test('a dropped request does not sign anybody out', () async {
    final storage = await _storageWith(signedIn: true);
    await storage.saveCachedUser(_arun.toJson());

    final bloc = _bloc(_Repo(const Left(NetworkFailure())), storage);
    addTearDown(bloc.close);

    bloc.add(const AuthCheckRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state, isA<AuthAuthenticated>(),
        reason: 'we failed to ask — that is not the server saying no');
    expect(storage.getCachedUser(), isNotNull);
  });

  test('a rejected token does sign them out, and forgets them', () async {
    final storage = await _storageWith(signedIn: true);
    await storage.saveCachedUser(_arun.toJson());

    final bloc = _bloc(_Repo(const Left(AuthFailure())), storage);
    addTearDown(bloc.close);

    bloc.add(const AuthCheckRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state, isA<AuthUnauthenticated>());
    expect(storage.getCachedUser(), isNull,
        reason: 'a stale cache would greet the next person by this name');
  });

  test('with no cache and no network, it does not pretend', () async {
    final storage = await _storageWith(signedIn: true);

    final bloc = _bloc(_Repo(const Left(NetworkFailure())), storage);
    addTearDown(bloc.close);

    bloc.add(const AuthCheckRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state, isA<AuthUnauthenticated>());
  });

  test('a successful check refreshes what is remembered', () async {
    final storage = await _storageWith(signedIn: true);
    const renamed = UserModel(
      id: 'u1',
      phoneNumber: '+919000000001',
      role: 'USER',
      isVerified: true,
      preferredLanguage: 'en',
      fullNameEn: 'Arun K',
    );

    final bloc = _bloc(_Repo(const Right(renamed)), storage);
    addTearDown(bloc.close);

    bloc.add(const AuthCheckRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(storage.getCachedUser()?['full_name_en'], 'Arun K');
  });

  test('a corrupt cache is treated as no cache, not a crash', () async {
    final storage = await _storageWith(
      signedIn: true,
      extra: {'fyc_cached_user': 'not json at all'},
    );

    final bloc = _bloc(_Repo(const Left(NetworkFailure())), storage);
    addTearDown(bloc.close);

    bloc.add(const AuthCheckRequested());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state, isA<AuthUnauthenticated>());
  });

  test('a restored session marker without a token does not open the app',
      () async {
    // The reinstall bug, exactly: Android auto-backup puts `fyc_has_session`
    // and the cached profile back on a FRESH install, but the token lives in
    // the Keystore and cannot travel. The app skipped the login screen and
    // opened as somebody it could not name — signed in on paper, anonymous in
    // fact, which is the "?" where the member's name belongs.
    final storage = await _storageWith(signedIn: true, withToken: false);
    await storage.saveCachedUser(_arun.toJson());

    final repo = _Repo(const Right(_arun));
    final bloc = _bloc(repo, storage);
    addTearDown(bloc.close);

    final states = <AuthState>[];
    bloc.stream.listen(states.add);

    bloc.add(const AuthCheckRequested());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(states.last, isA<AuthUnauthenticated>(),
        reason: 'no token is no session — the member lands on login, '
            'without needing the network to discover it');
    expect(storage.getCachedUser(), isNull,
        reason: 'the restored profile is cleared, so nothing lingers');
  });
}
