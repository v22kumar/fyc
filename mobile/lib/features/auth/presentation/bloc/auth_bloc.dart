import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import '../../domain/usecases/register_user_usecase.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/error/failures.dart';
import 'package:dio/dio.dart';
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
    on<AuthSessionInvalid>(_onSessionInvalid);
    on<AuthSendOtpRequested>(_onSendOtp);
    on<AuthVerifyOtpRequested>(_onVerifyOtp);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthGoogleSignInRequested>(_onGoogleSignIn);
    on<AuthGoogleBrowserOpened>((_, emit) => emit(const AuthGoogleInBrowser()));
    on<AuthGoogleSignInCancelled>(_onGoogleSignInCancelled);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthFirebasePnvRequested>(_onFirebasePnvRequested);
  }

  Future<void> _onCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    if (!_storage.isLoggedIn) {
      emit(const AuthUnauthenticated());
      return;
    }
    unawaited(_storage.hasToken().then((ok) {
      if (!ok && !isClosed) add(const AuthSessionInvalid());
    }).catchError((_) {}));
    final cached = _cachedUser();
    if (cached != null) {
      emit(AuthAuthenticated(cached));
    } else {
      emit(const AuthLoading());
    }
    final result = await _repository.getMe();
    result.fold(
      (f) {
        if (f is AuthFailure) {
          _storage.clearCachedUser();
          emit(const AuthUnauthenticated());
          return;
        }
        if (cached == null) emit(const AuthUnauthenticated());
      },
      (user) {
        _remember(user);
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onSessionInvalid(AuthSessionInvalid event, Emitter<AuthState> emit) async {
    await _storage.clearToken();
    await _storage.clearCachedUser();
    emit(const AuthUnauthenticated());
  }

  UserEntity? _cachedUser() {
    try {
      final raw = _storage.getCachedUser();
      return raw == null ? null : UserModel.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  void _remember(UserEntity user) {
    try {
      if (user is UserModel) _storage.saveCachedUser(user.toJson());
    } catch (_) {}
  }

  Future<void> _onSendOtp(AuthSendOtpRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _sendOtp(organizationId: event.organizationId, phoneNumber: event.phoneNumber);
    result.fold(
      (f) => emit(AuthFailureState(f.message)),
      (challenge) => emit(AuthOtpSent(verificationId: challenge.id, phoneNumber: event.phoneNumber, channel: challenge.channel)),
    );
  }

  Future<void> _onFirebasePnvRequested(AuthFirebasePnvRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final apiClient = sl<ApiClient>();
      // We will send the test token directly for now to bypass Twilio and verify the flow
      const testToken = 'AVweKohajldemHxif0W11cIpdIm8RIbljpFaXD_Oc7vymmQHAZBjW01CWcxLuV9K0YbZ74MCDa58c84Dcq438WCsjWVu-RM_UWHY_i-YJ3ID1GbAvZ6onBkY_N8h-ZXdieHfZBGI4fbeM6gK6yoi0l8G0A';
      
      final response = await apiClient.dio.post(
        '/auth/firebase/login',
        data: {
          'id_token': testToken,
          'organization_id': event.organizationId,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('access_token')) {
          // It's a token! User is logged in.
          final user = UserModel.fromJson(data['user']);
          _pendingEmail = null;
          _pendingFullName = null;
          _remember(user);
          _storage.saveToken(data['access_token']);
          emit(AuthAuthenticated(user));
          _registerFcmToken();
        } else if (data.containsKey('registration_token')) {
          // Needs registration
          final regToken = data['registration_token'];
          emit(AuthNeedsRegistration(
            organizationId: event.organizationId,
            phoneNumber: event.phoneNumber,
            registrationToken: regToken,
            email: _pendingEmail,
            fullName: _pendingFullName,
          ));
        } else {
          emit(const AuthFailureState("Unexpected response from Firebase PNV login"));
        }
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? e.message;
      emit(AuthFailureState(msg.toString()));
    } catch (e) {
      emit(AuthFailureState(e.toString()));
    }
  }

  Future<void> _onVerifyOtp(AuthVerifyOtpRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _verifyOtp(verificationId: event.verificationId, otpCode: event.otpCode);
    result.fold(
      (f) {
        if (f.message.contains('registration_token:')) {
          final token = f.message.split('registration_token:').last.trim();
          emit(AuthNeedsRegistration(organizationId: '', phoneNumber: '', registrationToken: token, email: _pendingEmail, fullName: _pendingFullName));
        } else if (f.message.contains('register') || f.message.contains('not registered')) {
          emit(const AuthNeedsRegistration(organizationId: '', phoneNumber: ''));
        } else {
          emit(AuthFailureState(f.message));
        }
      },
      (user) {
        _remember(user);
        emit(AuthAuthenticated(user));
        _registerFcmToken();
      },
    );
  }

  Future<void> _onRegister(AuthRegisterRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _registerUser(
      organizationId: event.organizationId,
      phoneNumber: event.phoneNumber,
      registrationToken: event.registrationToken,
      email: event.email,
      dateOfBirth: event.dateOfBirth,
      gender: event.gender,
      bloodGroup: event.bloodGroup,
      role: event.role,
      fullNameTa: event.fullNameTa,
      fullNameEn: event.fullNameEn,
      preferredLanguage: event.preferredLanguage,
    );
    result.fold(
      (f) => emit(AuthFailureState(f.message)),
      (user) {
        _remember(user);
        emit(AuthAuthenticated(user));
        _registerFcmToken();
      },
    );
  }

  String? _pendingEmail;
  String? _pendingFullName;
  int _googleAttempt = 0;

  Future<void> _onGoogleSignInCancelled(AuthGoogleSignInCancelled event, Emitter<AuthState> emit) async {
    _googleAttempt++;
    _repository.cancelGoogleBrowserSignIn();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onGoogleSignIn(AuthGoogleSignInRequested event, Emitter<AuthState> emit) async {
    final attempt = ++_googleAttempt;
    // The phone is only a claim. The network layer consumes this context after
    // Google returns an authenticated session and the backend separately decides
    // whether the number is free, then starts OTP proof.
    event.rememberPhone();
    emit(const AuthLoading());
    final result = await _repository.signInWithGoogle(
      organizationId: event.organizationId,
      onBrowserOpened: () {
        if (!isClosed && attempt == _googleAttempt) add(const AuthGoogleBrowserOpened());
      },
    );
    if (attempt != _googleAttempt) return;
    result.fold(
      (f) => emit(AuthFailureState(f.message)),
      (outcome) {
        switch (outcome) {
          case GoogleAuthSuccess(:final user):
            _pendingEmail = null;
            _pendingFullName = null;
            _remember(user);
            emit(AuthAuthenticated(user));
            _registerFcmToken();
          case GoogleAuthNeedsProfile(:final email, :final fullName):
            _pendingEmail = email;
            _pendingFullName = fullName;
            emit(AuthGoogleNeedsPhone(email: email, fullName: fullName));
        }
      },
    );
  }

  void _registerFcmToken() {
    try {
      FirebaseMessaging.instance.getToken().then((token) async {
        if (token == null) return;
        try {
          await _repository.registerFcmToken(token);
        } catch (_) {}
      }).catchError((_) {});
    } catch (_) {}
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _repository.logout();
    await _storage.clearCachedUser();
    emit(const AuthUnauthenticated());
  }
}
