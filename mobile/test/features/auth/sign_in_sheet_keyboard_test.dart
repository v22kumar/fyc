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

class _Repo implements AuthRepository {
  @override
  Future<Either<Failure, OtpChallenge>> sendOtp({
    required String organizationId,
    required String phoneNumber,
  }) async =>
      const Right(OtpChallenge(id: 'v_abc123456789', channel: 'sms'));

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

  testWidgets('the phone step opens the keyboard it actually needs',
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

    final phone = _fieldByKey(tester, 'sign-in-phone');
    expect(phone.keyboardType, TextInputType.phone);
    expect(phone.textCapitalization, TextCapitalization.none);
  });

  testWidgets('the three fields have distinct stable keys', (tester) async {
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

    expect(find.byKey(const ValueKey('sign-in-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-in-code')), findsNothing);
    expect(find.byKey(const ValueKey('sign-in-name')), findsNothing);
  });
}
