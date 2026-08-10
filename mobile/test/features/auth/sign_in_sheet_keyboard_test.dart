import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/features/auth/domain/entities/otp_challenge.dart';
import 'package:fyc_connect/features/auth/domain/entities/user_entity.dart';
import 'package:fyc_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:fyc_connect/features/auth/domain/usecases/register_user_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fyc_connect/features/auth/presentation/widgets/sign_in_sheet.dart';

/// Asked to type a name on a keypad with no letters.
///
/// All three steps of the sheet put a `TextField` at the same position in the
/// same list. With no key, Flutter matches by type and position, reuses one
/// element for all three, and keeps the open text-input connection — including
/// the keyboard the previous step configured. Phone and code are both numeric,
/// so it stayed invisible until the name step, which asked for a name and
/// opened a number pad.
///
/// This walks the real sheet through all three steps and reads back the
/// keyboard each one asks for.
class _Repo implements AuthRepository {
  @override
  Future<Either<Failure, OtpChallenge>> sendOtp({
    required String organizationId,
    required String phoneNumber,
  }) async =>
      const Right(OtpChallenge(id: 'v_abc123456789', channel: 'sms'));

  /// A number the club has never seen lands on "tell us your name" — the
  /// bloc reads the registration token out of this message.
  @override
  Future<Either<Failure, UserEntity>> verifyOtp({
    required String verificationId,
    required String otpCode,
  }) async =>
      const Left(AuthFailure('registration_token: tok-123'));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('not used by this test');
}

Future<void> _register() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorage(await SharedPreferences.getInstance());
  final repo = _Repo();
  await GetIt.I.reset();
  GetIt.I.registerSingleton<AuthBloc>(AuthBloc(
    sendOtp: SendOtpUseCase(repo),
    verifyOtp: VerifyOtpUseCase(repo),
    registerUser: RegisterUserUseCase(repo),
    repository: repo,
    storage: storage,
  ));
  GetIt.I.registerSingleton<LocalStorage>(storage);
}

TextField _fieldByKey(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key)));

void main() {
  tearDown(() => GetIt.I.reset());

  testWidgets('each step opens the keyboard it actually needs', (tester) async {
    await _register();
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: GetIt.I<AuthBloc>(),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => SignInSheet.ensure(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Step 1 — a phone number.
    expect(_fieldByKey(tester, 'sign-in-phone').keyboardType,
        TextInputType.phone);

    await tester.enterText(find.byKey(const ValueKey('sign-in-phone')),
        '9487984964');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    // Step 2 — six digits.
    expect(_fieldByKey(tester, 'sign-in-code').keyboardType,
        TextInputType.number);

    // Six digits auto-submits, and this number is new, so we land on the name.
    await tester.enterText(
        find.byKey(const ValueKey('sign-in-code')), '624684');
    await tester.pumpAndSettle();

    // Step 3 — the one that was broken. A name is letters.
    final name = _fieldByKey(tester, 'sign-in-name');
    expect(name.keyboardType, TextInputType.name,
        reason: 'a member was being asked to type their name on a number pad');
    expect(name.keyboardType, isNot(TextInputType.number));
    expect(name.textCapitalization, TextCapitalization.words);
  });

  testWidgets('the three fields are distinct elements, not one reused',
      (tester) async {
    await _register();
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: GetIt.I<AuthBloc>(),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => SignInSheet.ensure(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Keys are what stop Flutter reusing one element — and one open keyboard
    // connection — across all three steps.
    expect(find.byKey(const ValueKey('sign-in-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-in-code')), findsNothing);
    expect(find.byKey(const ValueKey('sign-in-name')), findsNothing);
  });
}
