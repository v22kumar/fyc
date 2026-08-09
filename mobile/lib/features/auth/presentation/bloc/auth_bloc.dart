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

    // Start from what we already know, so the app opens knowing whose it is.
    //
    // This used to go straight to AuthLoading and wait for the network. Home
    // reads the member's name off this state, so on a cold start — or a slow
    // connection, or a train in a tunnel — it rendered "Good Morning" with
    // nothing after it and a `?` where the initial goes, for somebody who had
    // been signed in for months.
    final cached = _cachedUser();
    if (cached != null) {
      emit(AuthAuthenticated(cached));
    } else {
      emit(const AuthLoading());
    }

    final result = await _repository.getMe();
    result.fold(
      (f) {
        // Only the server saying no means signed out.
        //
        // Every failure used to land here as AuthUnauthenticated — a dropped
        // request, a 500, a timeout — which silently un-personalised the app
        // while the tokens sat valid in storage. A 401 is the token being
        // rejected and is worth acting on; everything else is us failing to
        // ask, and the honest response to that is to keep what we last knew.
        if (f is AuthFailure) {
          _storage.clearCachedUser();
          emit(const AuthUnauthenticated());
          return;
        }
        if (cached == null) emit(const AuthUnauthenticated());
      },
      (user) {
        _remember(user);
        _remember(user);
        emit(AuthAuthenticated(user));
      },
    );
  }

  /// The last profile the server confirmed, read back from disk.
  ///
  /// Returns null on anything unexpected — a cache that cannot be parsed is a
  /// cache that does not exist, and this must never be the thing that stops
  /// the app opening.
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
    } catch (_) {
      // Best-effort. Failing to cache must never fail the sign-in.
    }
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
      (verificationId) {
        // The datasource packs "<id>|<channel>" so the transport stays a plain
        // String all the way through the existing use-case signature.
        final parts = verificationId.split('|');
        emit(AuthOtpSent(
          verificationId: parts.first,
          phoneNumber: event.phoneNumber,
          channel: parts.length > 1 ? parts[1] : null,
        ));
      },
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
        if (f.message.contains('registration_token:')) {
          final token = f.message.split('registration_token:').last.trim();
          emit(AuthNeedsRegistration(
            organizationId: '', 
            phoneNumber: '', 
            registrationToken: token,
            email: _pendingEmail,
            fullName: _pendingFullName,
          ));
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

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
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
      (outcome) {
        switch (outcome) {
          case GoogleAuthSuccess(:final user):
            _pendingEmail = null;
            _pendingFullName = null;
            _remember(user);
        emit(AuthAuthenticated(user));
            _registerFcmToken();
          case GoogleAuthNeedsProfile(:final email, :final fullName):
            // New Google member — carry the Google name/email and route them to
            // phone verification (the account is created only after OTP), rather
            // than dead-ending in a snackbar.
            _pendingEmail = email;
            _pendingFullName = fullName;
            emit(AuthGoogleNeedsPhone(email: email, fullName: fullName));
        }
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
        try {
          await _repository.registerFcmToken(token);
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
    // Signing out takes the remembered profile with it. A cache that outlived
    // the session would greet the next person to open the app by the last
    // person's name.
    await _storage.clearCachedUser();
    emit(const AuthUnauthenticated());
  }
}
