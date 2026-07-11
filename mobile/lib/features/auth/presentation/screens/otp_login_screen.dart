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
import '../../../../core/storage/local_storage.dart';
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
  String _orgId = ApiConstants.defaultOrgId;
  bool _otpSent = false;
  String _verificationId = '';
  String _phoneNumber = '';

  bool _isPasswordLogin = false;
  bool _localLoading = false;
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _pwdFormKey = GlobalKey<FormState>();

  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

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
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _aurora.dispose();
    super.dispose();
  }

  String get _otpCode => _otpCtrls.map((c) => c.text).join();

  void _onOtpDigit(int index, String value) {
    if (value.isNotEmpty && index < 5) _otpFocus[index + 1].requestFocus();
    if (value.isEmpty && index > 0) _otpFocus[index - 1].requestFocus();
    if (_otpCode.length == 6) _verifyOtp();
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ta = sl<LocalStorage>().getLang() == 'ta';

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          setState(() {
            _otpSent = true;
            _verificationId = state.verificationId;
            _phoneNumber = state.phoneNumber;
          });
        } else if (state is AuthAuthenticated) {
          context.go(ApiConstants.useAppShellV2 ? '/app' : '/home');
        } else if (state is AuthNeedsRegistration) {
          context.go('/register', extra: {
            'organizationId': _orgId,
            'phoneNumber': _phoneNumber,
          });
        } else if (state is AuthFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.accent,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: tr(en: 'Retry', ta: 'மீண்டும்', hi: 'पुनः प्रयास', ml: 'വീണ്ടും ശ്രമിക്കുക'),
                textColor: Colors.white,
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
          foregroundColor: Colors.white,
          leading: _otpSent
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => setState(() {
                    _otpSent = false;
                    for (final c in _otpCtrls) c.clear();
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
                  'assets/images/auth_bg.png',
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
                        color: const Color(0xFF0F5132).withOpacity(0.52),
                      ),
                    ),
                    Positioned(
                      right: -60.0 + 80 * math.sin(t * 0.30 + 1.4),
                      top: 150.0 + 50 * math.cos(t * 0.45 + 0.7),
                      child: _LoginBlob(
                        size: 260,
                        color: const Color(0xFF16A34A).withOpacity(0.28),
                      ),
                    ),
                    Positioned(
                      left: 40.0 + 60 * math.sin(t * 0.62 + 2.0),
                      bottom: 40.0 + 80 * math.cos(t * 0.42 + 1.5),
                      child: _LoginBlob(
                        size: 200,
                        color: const Color(0xFFD4AF37).withOpacity(0.07),
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

            // ── Form card ─────────────────────────────────────────────
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final isLoading = state is AuthLoading;
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
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/fyc_mark.png',
                            width: 64,
                            height: 64,
                            errorBuilder: (_, __, ___) =>
                                const Text('🌱', style: TextStyle(fontSize: 36)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'FYC Connect',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            en: 'Joining hands in social service',
                            ta: 'சமூக சேவையில் இணைவோம்',
                            hi: 'सामाजिक सेवा में जुड़ें',
                            ml: 'സാമൂഹിക സേവനത്തിൽ ഒന്നിക്കാം',
                          ),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
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
                            tr(
                              en: 'What is this app?',
                              ta: 'இது என்ன செயலி?',
                              hi: 'यह ऐप किस लिए है?',
                              ml: 'ഇതെന്ത് ആപ്പാണ്?',
                            ),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withOpacity(0.4),
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
                                color: Colors.white.withOpacity(0.93),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
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
                                        ? tr(
                                            en: 'Official Login',
                                            ta: 'குழுவினர் உள்நுழைவு',
                                            hi: 'आधिकारिक लॉगिन',
                                            ml: 'ഔദ്യോഗിക ലോഗിൻ',
                                          )
                                        : (_otpSent
                                            ? l.enterOtp
                                            : l.enterPhoneNumber),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (_otpSent) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${l.otpSentTo} $_phoneNumber',
                                      style: const TextStyle(
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
                                              hintText: tr(
                                                en: 'Username or Phone',
                                                ta: 'பயனர் பெயர் அல்லது அலைபேசி',
                                                hi: 'उपयोगकर्ता नाम या फ़ोन',
                                                ml: 'ഉപയോക്തൃനാമം അല്ലെങ്കിൽ ഫോൺ',
                                              ),
                                              prefixIcon: const Icon(
                                                  Icons.person_outline),
                                              label: Text(tr(
                                                en: 'Username',
                                                ta: 'பயனர் பெயர்',
                                                hi: 'उपयोगकर्ता नाम',
                                                ml: 'ഉപയോക്തൃനാമം',
                                              )),
                                            ),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? tr(
                                                        en: 'Required',
                                                        ta: 'உள்ளிடவும்',
                                                        hi: 'आवश्यक',
                                                        ml: 'ആവശ്യമാണ്',
                                                      )
                                                    : null,
                                          ),
                                          const SizedBox(height: 14),
                                          TextFormField(
                                            controller: _passwordCtrl,
                                            obscureText: true,
                                            decoration: InputDecoration(
                                              hintText: tr(
                                                en: 'Password',
                                                ta: 'கடவுச்சொல்',
                                                hi: 'पासवर्ड',
                                                ml: 'പാസ്‌വേഡ്',
                                              ),
                                              prefixIcon: const Icon(
                                                  Icons.lock_outline),
                                              label: Text(tr(
                                                en: 'Password',
                                                ta: 'கடவுச்சொல்',
                                                hi: 'पासवर्ड',
                                                ml: 'പാസ്‌വേഡ്',
                                              )),
                                            ),
                                            validator: (v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? tr(
                                                        en: 'Required',
                                                        ta: 'உள்ளிடவும்',
                                                        hi: 'आवश्यक',
                                                        ml: 'ആവശ്യമാണ്',
                                                      )
                                                    : null,
                                          ),
                                          const SizedBox(height: 20),
                                          ElevatedButton(
                                            onPressed: _localLoading
                                                ? null
                                                : _submitPasswordLogin,
                                            child: _localLoading
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                            color: Colors.white,
                                                            strokeWidth: 2),
                                                  )
                                                : Text(tr(
                                                    en: 'Login',
                                                    ta: 'உள்நுழைக',
                                                    hi: 'लॉगिन',
                                                    ml: 'ലോഗിൻ',
                                                  )),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // ── Phone step ────────────────────
                                  ] else if (!_otpSent) ...[
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
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                            color: Colors.white,
                                                            strokeWidth: 2),
                                                  )
                                                : Text(l.sendOtp),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // ── OTP step ──────────────────────
                                  ] else ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(6, (i) {
                                        return SizedBox(
                                          width: 44,
                                          height: 54,
                                          child: TextFormField(
                                            controller: _otpCtrls[i],
                                            focusNode: _otpFocus[i],
                                            textAlign: TextAlign.center,
                                            keyboardType:
                                                TextInputType.number,
                                            maxLength: 1,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            decoration: InputDecoration(
                                              counterText: '',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              contentPadding:
                                                  EdgeInsets.zero,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            onChanged: (v) =>
                                                _onOtpDigit(i, v),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed:
                                          isLoading ? null : _verifyOtp,
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                      color: Colors.white,
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
                                              ? tr(
                                                  en: 'Back to OTP Login',
                                                  ta: 'உறுப்பினர் உள்நுழைவு (OTP)',
                                                  hi: 'OTP लॉगिन पर वापस',
                                                  ml: 'OTP ലോഗിനിലേക്ക് മടങ്ങുക',
                                                )
                                              : tr(
                                                  en: 'Club Official Login',
                                                  ta: 'குழுவினர் உள்நுழைவு (கடவுச்சொல்)',
                                                  hi: 'क्लब आधिकारिक लॉगिन',
                                                  ml: 'ക്ലബ് ഔദ്യോഗിക ലോഗിൻ',
                                                ),
                                          style: const TextStyle(
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
                                          tr(en: 'OR', ta: 'அல்லது', hi: 'या', ml: 'അല്ലെങ്കിൽ'),
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12),
                                        ),
                                      ),
                                      const Expanded(child: Divider()),
                                    ]),
                                    const SizedBox(height: 12),
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
                                          : Image.network(
                                              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                              height: 18,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                      Icons.g_mobiledata,
                                                      size: 18),
                                            ),
                                      label: Text(tr(
                                          en: 'Continue with Google',
                                          ta: 'Google மூலம் தொடரவும்',
                                          hi: 'Google के साथ जारी रखें',
                                          ml: 'Google ഉപയോഗിച്ച് തുടരുക')),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize:
                                            const Size.fromHeight(48),
                                        side: const BorderSide(
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(l.noAccount,
                                            style: const TextStyle(
                                                color:
                                                    AppColors.textSecondary,
                                                fontSize: 13)),
                                        TextButton(
                                          onPressed: () =>
                                              context.go('/register',
                                                  extra: {
                                                'organizationId': _orgId,
                                                'phoneNumber':
                                                    _phoneCtrl.text.trim(),
                                              }),
                                          child: Text(l.register),
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
