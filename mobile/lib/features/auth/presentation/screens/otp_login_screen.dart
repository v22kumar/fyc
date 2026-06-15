import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _orgId = ApiConstants.defaultOrgId;
  bool _otpSent = false;
  String _verificationId = '';
  String _phoneNumber = '';

  // OTP fields
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  String get _otpCode =>
      _otpCtrls.map((c) => c.text).join();

  void _onOtpDigit(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _otpFocus[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocus[index - 1].requestFocus();
    }
    if (_otpCode.length == 6) {
      _verifyOtp();
    }
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          setState(() {
            _otpSent = true;
            _verificationId = state.verificationId;
            _phoneNumber = state.phoneNumber;
          });
        } else if (state is AuthAuthenticated) {
          context.go('/home');
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
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(l.appName),
          leading: _otpSent
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    _otpSent = false;
                    for (final c in _otpCtrls) c.clear();
                  }),
                )
              : null,
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.paddingPage),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Header
                  Text(
                    _otpSent ? l.enterOtp : l.enterPhoneNumber,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_otpSent)
                    Text(
                      '${l.otpSentTo} $_phoneNumber',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  const SizedBox(height: 32),

                  if (!_otpSent) ...[
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: l.phoneHint,
                              prefixIcon: const Icon(Icons.phone_outlined),
                              label: Text(l.enterPhoneNumber),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return l.enterPhoneNumber;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: isLoading ? null : _sendOtp,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(l.sendOtp),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // OTP boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        return SizedBox(
                          width: 48,
                          height: 56,
                          child: TextFormField(
                            controller: _otpCtrls[i],
                            focusNode: _otpFocus[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            onChanged: (v) => _onOtpDigit(i, v),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isLoading ? null : _verifyOtp,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(l.verifyOtp),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: isLoading ? null : _sendOtp,
                        child: Text(l.resendOtp),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  if (!_otpSent) ...[
                    // Divider
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 16),

                    // Google Sign-In button
                    OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => context.read<AuthBloc>().add(
                                AuthGoogleSignInRequested(organizationId: _orgId),
                              ),
                      icon: Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        height: 20,
                        errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 20),
                      ),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l.noAccount,
                          style: const TextStyle(color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => context.go('/register', extra: {
                          'organizationId': _orgId,
                          'phoneNumber': _phoneCtrl.text.trim(),
                        }),
                        child: Text(l.register),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
