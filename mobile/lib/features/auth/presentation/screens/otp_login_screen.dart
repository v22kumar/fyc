import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/design_system/patterns/kolam_background.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../service_locator.dart';

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen>
    with TickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final String _orgId = ApiConstants.defaultOrgId;
  bool _otpSent = false;
  String _verificationId = '';
  String _phoneNumber = '';

  bool _isPasswordLogin = false;
  bool _localLoading = false;
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _pwdFormKey = GlobalKey<FormState>();

  // Single underlying OTP field (Pinput-style) so paste + SMS autofill deliver
  // the whole 6-digit code at once; six visual boxes are painted over it.
  final TextEditingController _otpCtrl = TextEditingController();
  final FocusNode _otpFocus = FocusNode();

  // Set when a brand-new Google sign-up is finishing via phone verification —
  // shows a banner so the user knows why they're being asked for a phone.
  String? _googleFinishName;

  late AnimationController _aurora;

  @override
  void initState() {
    super.initState();
    _aurora = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    _aurora.dispose();
    super.dispose();
  }

  String get _otpCode => _otpCtrl.text;

  void _onOtpChanged(String value) {
    // Auto-submit as soon as the full code is present (typed, pasted, or
    // delivered by SMS autofill).
    setState(() {});
    if (value.length == 6) _verifyOtp();
  }

  void _sendOtp() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthSendOtpRequested(
          organizationId: _orgId,
          phoneNumber: _phoneCtrl.text.trim(),
        ));
  }

  void _verifyOtp() {
    if (_otpCode.length != 6) return;
    context.read<AuthBloc>().add(AuthVerifyOtpRequested(
          verificationId: _verificationId,
          otpCode: _otpCode,
        ));
  }

  Future<void> _submitPasswordLogin() async {
    if (!_pwdFormKey.currentState!.validate()) return;
    setState(() => _localLoading = true);

    final repository = sl<AuthRepository>();
    final result = await repository.loginWithPassword(
      organizationId: _orgId,
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
    );

    result.fold(
      (failure) {
        setState(() => _localLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.accent,
          ),
        );
      },
      (user) {
        setState(() => _localLoading = false);
        context.read<AuthBloc>().add(const AuthCheckRequested());
      },
    );
  }

  /// Six visual boxes painted over a single transparent field, so a pasted code
  /// or an SMS-autofilled code (AutofillHints.oneTimeCode) fills all six at once
  /// — while still looking like separate OTP boxes. Tapping anywhere focuses it.
  Widget _buildOtpField() {
    final code = _otpCtrl.text;
    return AutofillGroup(
      child: GestureDetector(
        onTap: () => _otpFocus.requestFocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                final filled = i < code.length;
                final isCurrent = i == code.length;
                return Container(
                  width: 44,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isCurrent && _otpFocus.hasFocus)
                          ? AppColors.primary
                          : AppColors.border,
                      width: (isCurrent && _otpFocus.hasFocus) ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    filled ? code[i] : '',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }),
            ),
            // Transparent capture field on top of the boxes.
            Positioned.fill(
              child: TextField(
                controller: _otpCtrl,
                focusNode: _otpFocus,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(color: Colors.transparent, height: 0.01),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _onOtpChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ta = trLang() == 'ta';

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          setState(() {
            _otpSent = true;
            _verificationId = state.verificationId;
            _phoneNumber = state.phoneNumber;
          });
        } else if (state is AuthGoogleNeedsPhone) {
          // New Google account: drop the user on the phone step to verify a
          // number; the Google name/email is carried through to registration.
          setState(() {
            _isPasswordLogin = false;
            _otpSent = false;
            _otpCtrl.clear();
            _googleFinishName = state.fullName.isNotEmpty ? state.fullName : state.email;
          });
        } else if (state is AuthAuthenticated) {
          context.go(ApiConstants.useAppShellV2 ? '/app' : '/home');
        } else if (state is AuthNeedsRegistration) {
          if (state.registrationToken != null) {
            context.go('/register', extra: {
              'organizationId': _orgId,
              'phoneNumber': state.phoneNumber.isNotEmpty ? state.phoneNumber : _phoneNumber,
              'registrationToken': state.registrationToken,
              'email': state.email,
              'fullName': state.fullName,
            });
          }
        } else if (state is AuthFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.accent,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: trId('retry_3'),
                textColor: AppColors.background,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBg,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.background,
          leading: _otpSent
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.background),
                  onPressed: () => setState(() {
                    _otpSent = false;
                    _otpCtrl.clear();
                  }),
                )
              : null,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Photographic backdrop (faded) ─────────────────────────
            Positioned.fill(
              child: Opacity(
                opacity: 0.30,
                child: Image.asset(
                  'assets/images/auth_bg.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            // ── Aurora background ─────────────────────────────────────
            AnimatedBuilder(
              animation: _aurora,
              builder: (_, __) {
                final t = _aurora.value * 2 * math.pi;
                return Stack(
                  children: [
                    Positioned(
                      left: -80.0 + 60 * math.sin(t * 0.50),
                      top: -60.0 + 70 * math.cos(t * 0.38),
                      child: _LoginBlob(
                        size: 300,
                        color: const Color(0xFF0F5132).withValues(alpha: 0.52),
                      ),
                    ),
                    Positioned(
                      right: -60.0 + 80 * math.sin(t * 0.30 + 1.4),
                      top: 150.0 + 50 * math.cos(t * 0.45 + 0.7),
                      child: _LoginBlob(
                        size: 260,
                        color: const Color(0xFF16A34A).withValues(alpha: 0.28),
                      ),
                    ),
                    Positioned(
                      left: 40.0 + 60 * math.sin(t * 0.62 + 2.0),
                      bottom: 40.0 + 80 * math.cos(t * 0.42 + 1.5),
                      child: _LoginBlob(
                        size: 200,
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.07),
                      ),
                    ),
                  ],
                );
              },
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          // Kolam texture over the aurora, under the content (MD3 redesign §3.4).
          KolamTextureLayer(color: AppColors.background),

            // ── Form card ─────────────────────────────────────────────
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final inBrowser = state is AuthGoogleInBrowser;
                final isLoading = state is AuthLoading || inBrowser;
                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      children: [
                        // Logo + brand
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.background.withValues(alpha: 0.08),
                            border: Border.all(
                              color: AppColors.background.withValues(alpha: 0.18),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/fyc_mark.webp',
                            width: 64,
                            height: 64,
                            errorBuilder: (_, __, ___) =>
                                const Text('🌱', style: TextStyle(fontSize: 36)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          trId('fyc_connect'),
                          style: TextStyle(
                            color: AppColors.background,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trId('joining_hands_in_social_service'),
                          style: TextStyle(
                            color: AppColors.background.withValues(alpha: 0.55),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => context.push('/about'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            trId('what_is_this_app'),
                            style: TextStyle(
                              color: AppColors.background.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.background.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Glass card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(alpha: 0.93),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.background.withValues(alpha: 0.6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.textPrimary.withValues(alpha: 0.25),
                                    blurRadius: 40,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    _isPasswordLogin
                                        ? trId('official_login')
                                        : (_otpSent
                                            ? l.enterOtp
                                            : l.enterPhoneNumber),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (_otpSent) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${l.otpSentTo} $_phoneNumber',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13),
                                    ),
                                  ],
                                  const SizedBox(height: 20),

                                  // ── Password login ────────────────
                                  if (_isPasswordLogin) ...[
                                    Form(
                                      key: _pwdFormKey,
                                      child: Column(
                                        children: [
                                          TextFormField(
                                            controller: _usernameCtrl,
                                            decoration: InputDecoration(
                                              hintText: trId('username_or_phone'),
                                              prefixIcon: const Icon(
                                                  Icons.person_outline),
                                              label: Text(trId('username')),
                                            ),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? trId('required')
                                                    : null,
                                          ),
                                          const SizedBox(height: 14),
                                          TextFormField(
                                            controller: _passwordCtrl,
                                            obscureText: true,
                                            decoration: InputDecoration(
                                              hintText: trId('password'),
                                              prefixIcon: const Icon(
                                                  Icons.lock_outline),
                                              label: Text(trId('password')),
                                            ),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? trId('required')
                                                    : null,
                                          ),
                                          const SizedBox(height: 20),
                                          ElevatedButton(
                                            onPressed: _localLoading
                                                ? null
                                                : _submitPasswordLogin,
                                            child: _localLoading
                                                ? SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                            color: AppColors.background,
                                                            strokeWidth: 2),
                                                  )
                                                : Text(trId('login')),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // ── Phone step ────────────────────
                                  ] else if (!_otpSent) ...[
                                    if (_googleFinishName != null) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySurface,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.primary),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.verified_user_rounded,
                                                color: AppColors.primary, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                trId('verify_phone_to_finish_google'),
                                                style: TextStyle(
                                                    color: AppColors.textPrimary,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          TextFormField(
                                            controller: _phoneCtrl,
                                            keyboardType:
                                                TextInputType.phone,
                                            decoration: InputDecoration(
                                              hintText: l.phoneHint,
                                              prefixIcon: const Icon(
                                                  Icons.phone_outlined),
                                              label:
                                                  Text(l.enterPhoneNumber),
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .allow(RegExp(r'[+\d]')),
                                            ],
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? l.enterPhoneNumber
                                                    : null,
                                          ),
                                          const SizedBox(height: 20),
                                          ElevatedButton(
                                            onPressed:
                                                isLoading ? null : _sendOtp,
                                            child: isLoading
                                                ? SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                            color: AppColors.background,
                                                            strokeWidth: 2),
                                                  )
                                                : Text(l.sendOtp),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // ── OTP step ──────────────────────
                                  ] else ...[
                                    _buildOtpField(),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed:
                                          isLoading ? null : _verifyOtp,
                                      child: isLoading
                                          ? SizedBox(
                                              height: 20,
                                              width: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                      color: AppColors.background,
                                                      strokeWidth: 2),
                                            )
                                          : Text(l.verifyOtp),
                                    ),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: TextButton(
                                        onPressed:
                                            isLoading ? null : _sendOtp,
                                        child: Text(l.resendOtp),
                                      ),
                                    ),
                                  ],

                                  // ── Toggle + extras (non-OTP steps) ─
                                  if (!_otpSent) ...[
                                    const SizedBox(height: 16),
                                    Center(
                                      child: TextButton(
                                        onPressed: () => setState(() {
                                          _isPasswordLogin =
                                              !_isPasswordLogin;
                                        }),
                                        child: Text(
                                          _isPasswordLogin
                                              ? trId('back_to_otp_login')
                                              : trId('club_official_login'),
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],

                                  if (!_otpSent && !_isPasswordLogin) ...[
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(
                                          trId('or'),
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12),
                                        ),
                                      ),
                                      const Expanded(child: Divider()),
                                    ]),
                                    const SizedBox(height: 12),
                                    // While the browser holds the sign-in there
                                    // is nothing to wait for on this screen —
                                    // Google may never come back at all — so the
                                    // button becomes the way out rather than a
                                    // disabled spinner.
                                    if (inBrowser) ...[
                                      Text(
                                        trId('google_finish_in_browser'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () => context
                                            .read<AuthBloc>()
                                            .add(const AuthGoogleSignInCancelled()),
                                        child: Text(trId('cancel')),
                                      ),
                                    ],
                                    OutlinedButton.icon(
                                      onPressed: isLoading
                                          ? null
                                          : () => context
                                              .read<AuthBloc>()
                                              .add(
                                                AuthGoogleSignInRequested(
                                                    organizationId: _orgId),
                                              ),
                                      icon: isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          // Bundled icon, not a network image —
                                          // village connections are slow/offline
                                          // and a network logo often failed to load.
                                          : Icon(Icons.g_mobiledata, size: 24, color: AppColors.primary),
                                      label: Text(trId('continue_with_google')),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize:
                                            const Size.fromHeight(48),
                                        side: BorderSide(
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          trId('enter_phone_to_get_started'),
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _LoginBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
