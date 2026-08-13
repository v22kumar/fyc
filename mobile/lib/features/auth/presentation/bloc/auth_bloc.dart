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
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!_storage.isLoggedIn) {
      emit(const AuthUnauthenticated());
      return;
    }

    // A session marker without a token is not a session.
    //
    // Android auto-backup restores SharedPreferences onto a fresh install —
    // including `fyc_has_session` and the cached profile — but the token sits
    // in the Keystore and does not come with them. The app read the restored
    // flag, skipped the login screen, and opened as somebody it could not
    // name: signed in on paper, anonymous in fact. Backup is refused in the
    // manifest now; this heals installs already carrying the restored flag.
    //
    // Deliberately NOT awaited: this reads the Keystore over a platform
    // channel, and the app must open at the speed of local data whatever the
    // keyring is doing. It arrives in milliseconds and signs out cleanly if
    // the marker was lying.
    unawaited(_storage.hasToken().then((ok) {
      if (!ok && !isClosed) add(const AuthSessionInvalid());
    }).catchError((_) {/* cannot tell — leave the session alone */}));

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

  /// The stored marker claimed a session the Keystore cannot back. Clear
  /// both, so the member gets the login screen instead of an app that does
  /// not know who they are — and so it cannot recur on the next open.
  Future<void> _onSessionInvalid(
    AuthSessionInvalid event,
    Emitter<AuthState> emit,
  ) async {
    await _storage.clearToken();
    await _storage.clearCachedUser();
    emit(const AuthUnauthenticated());
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
      (challenge) => emit(AuthOtpSent(
        verificationId: challenge.id,
        phoneNumber: event.phoneNumber,
        channel: challenge.channel,
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

  /// Which attempt is current.
  ///
  /// A cancelled sign-in is still a Future in flight — the poll loop unwinds,
  /// the native plugin may still answer — and its result must not be allowed to
  /// land on a screen the member has already taken back. Counting attempts is
  /// enough: anything stamped with an older number is ignored.
  int _googleAttempt = 0;

  Future<void> _onGoogleSignInCancelled(
    AuthGoogleSignInCancelled event,
    Emitter<AuthState> emit,
  ) async {
    _googleAttempt++;
    _repository.cancelGoogleBrowserSignIn();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onGoogleSignIn(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final attempt = ++_googleAttempt;
    emit(const AuthLoading());
    final result = await _repository.signInWithGoogle(
      organizationId: event.organizationId,
      onBrowserOpened: () {
        if (!isClosed && attempt == _googleAttempt) {
          add(const AuthGoogleBrowserOpened());
        }
      },
    );
    // Cancelled while this was in flight: the member is looking at the login
    // screen again, and an answer to a question they withdrew would either sign
    // them in unasked or throw an error at them out of nowhere.
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
