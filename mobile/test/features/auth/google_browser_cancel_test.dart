import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:fyc_connect/features/auth/domain/usecases/register_user_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_event.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_state.dart';

/// A member left holding a spinner nobody will ever end.
///
/// Google refuses some requests *before* redirecting — a redirect_uri_mismatch
/// is decided on Google's own page and never reaches our callback — so neither
/// the server nor the app is told the attempt died. The app polls to its
/// three-minute timeout and the button spins throughout. From where the member
/// is standing that is a frozen app, and it was reported as one.
///
/// So the browser wait is now a state of its own, with a way out of it.
class _Repo implements AuthRepository {
  /// Held open, the way a real browser sign-in is held open.
  final Completer<Either<Failure, GoogleAuthOutcome>> pending = Completer();
  bool cancelled = false;
  void Function()? _announce;

  @override
  Future<Either<Failure, GoogleAuthOutcome>> signInWithGoogle({
    required String organizationId,
    void Function()? onBrowserOpened,
  }) {
    _announce = onBrowserOpened;
    return pending.future;
  }

  /// The browser opening, at the moment a test chooses.
  void openBrowser() => _announce?.call();

  @override
  void cancelGoogleBrowserSignIn() => cancelled = true;

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('not used by these tests');
}

AuthBloc _bloc(_Repo repo, LocalStorage storage) => AuthBloc(
      sendOtp: SendOtpUseCase(repo),
      verifyOtp: VerifyOtpUseCase(repo),
      registerUser: RegisterUserUseCase(repo),
      repository: repo,
      storage: storage,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorage(await SharedPreferences.getInstance());
  });

  test('leaving for the browser is a state the screen can name', () async {
    final repo = _Repo();
    final bloc = _bloc(repo, storage);
    final seen = <AuthState>[];
    final sub = bloc.stream.listen(seen.add);

    bloc.add(const AuthGoogleSignInRequested(organizationId: 'org'));
    await Future<void>.delayed(Duration.zero);
    repo.openBrowser();
    await Future<void>.delayed(Duration.zero);

    expect(seen.whereType<AuthGoogleInBrowser>(), isNotEmpty,
        reason: 'a spinner with no words was read as a frozen app');

    await sub.cancel();
    await bloc.close();
  });

  test('cancelling gives the login screen back, and tells the poll to stop',
      () async {
    final repo = _Repo();
    final bloc = _bloc(repo, storage);

    bloc.add(const AuthGoogleSignInRequested(organizationId: 'org'));
    await Future<void>.delayed(Duration.zero);
    repo.openBrowser();
    await Future<void>.delayed(Duration.zero);

    bloc.add(const AuthGoogleSignInCancelled());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, isA<AuthUnauthenticated>(),
        reason: 'the member asked for the screen back');
    expect(repo.cancelled, isTrue,
        reason: 'a poll left running would keep the old attempt alive');

    await bloc.close();
  });

  test('an answer that arrives after cancelling is ignored', () async {
    final repo = _Repo();
    final bloc = _bloc(repo, storage);

    bloc.add(const AuthGoogleSignInRequested(organizationId: 'org'));
    await Future<void>.delayed(Duration.zero);
    repo.openBrowser();
    await Future<void>.delayed(Duration.zero);
    bloc.add(const AuthGoogleSignInCancelled());
    await Future<void>.delayed(Duration.zero);

    // The abandoned attempt unwinds a moment later, as it really does: the
    // native plugin answers, or the poll loop reaches its timeout.
    repo.pending.complete(const Left(ServerFailure()));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state, isA<AuthUnauthenticated>(),
        reason: 'an error from a withdrawn question must not land on the '
            'screen the member has already taken back');

    await bloc.close();
  });
}
