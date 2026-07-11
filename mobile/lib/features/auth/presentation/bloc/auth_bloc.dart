import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import '../../domain/usecases/register_user_usecase.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SendOtpUseCase _sendOtp;
  final VerifyOtpUseCase _verifyOtp;
  final RegisterUserUseCase _registerUser;
  final AuthRepository _repository;
  final LocalStorage _storage;

  AuthBloc({
    required SendOtpUseCase sendOtp,
    required VerifyOtpUseCase verifyOtp,
    required RegisterUserUseCase registerUser,
    required AuthRepository repository,
    required LocalStorage storage,
  })  : _sendOtp = sendOtp,
        _verifyOtp = verifyOtp,
        _registerUser = registerUser,
        _repository = repository,
        _storage = storage,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSendOtpRequested>(_onSendOtp);
    on<AuthVerifyOtpRequested>(_onVerifyOtp);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthGoogleSignInRequested>(_onGoogleSignIn);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!_storage.isLoggedIn) {
      emit(const AuthUnauthenticated());
      return;
    }
    emit(const AuthLoading());
    final result = await _repository.getMe();
    result.fold(
      (f) => emit(const AuthUnauthenticated()),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onSendOtp(
    AuthSendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _sendOtp(
      organizationId: event.organizationId,
      phoneNumber: event.phoneNumber,
    );
    result.fold(
      (f) => emit(AuthFailureState(f.message)),
      (verificationId) => emit(AuthOtpSent(
        verificationId: verificationId,
        phoneNumber: event.phoneNumber,
      )),
    );
  }

  Future<void> _onVerifyOtp(
    AuthVerifyOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _verifyOtp(
      verificationId: event.verificationId,
      otpCode: event.otpCode,
    );
    result.fold(
      (f) {
        if (f.message.contains('register') || f.message.contains('not registered')) {
          emit(const AuthNeedsRegistration(organizationId: '', phoneNumber: ''));
        } else {
          emit(AuthFailureState(f.message));
        }
      },
      (user) {
        emit(AuthAuthenticated(user));
        _registerFcmToken();
      },
    );
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _registerUser(
      organizationId: event.organizationId,
      phoneNumber: event.phoneNumber,
      email: event.email,
      dateOfBirth: event.dateOfBirth,
      role: event.role,
      fullNameTa: event.fullNameTa,
      fullNameEn: event.fullNameEn,
      preferredLanguage: event.preferredLanguage,
    );
    result.fold(
      (f) => emit(AuthFailureState(f.message)),
      (user) {
        emit(AuthAuthenticated(user));
        _registerFcmToken();
      },
    );
  }

  Future<void> _onGoogleSignIn(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _repository.signInWithGoogle(
      organizationId: event.organizationId,
    );
    result.fold(
      (f) => emit(AuthFailureState(f.message)),
      (user) {
        emit(AuthAuthenticated(user));
        _registerFcmToken();
      },
    );
  }

  /// Fire-and-forget: register device FCM token with backend after login.
  void _registerFcmToken() {
    // `FirebaseMessaging.instance` throws SYNCHRONOUSLY if Firebase failed to
    // initialize (missing/outdated Play Services — not uncommon on cheap
    // village phones, and always true in this file's unit tests), before
    // .getToken() ever runs — so a synchronous try/catch is required; the
    // async .catchError() below only covers errors after that point.
    try {
      FirebaseMessaging.instance.getToken().then((token) async {
        if (token == null) return;
        final client = sl<ApiClient>();
        try {
          await client.dio.post(ApiConstants.fcmToken, data: {'token': token});
        } catch (_) {}
      }).catchError((_) {});
    } catch (_) {
      // Best-effort: push registration should never block login.
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }
}
