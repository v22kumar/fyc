import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/services/error_reporter.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class SignInSheet {
  SignInSheet._();

  static Future<bool> ensure(BuildContext context) async {
    if (sl<AuthBloc>().state is AuthAuthenticated) return true;
    if (!context.mounted) return false;
    final signedIn = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: sl<AuthBloc>(),
        child: const _SignInSheet(),
      ),
    );
    return signedIn ?? false;
  }
}

enum _Step { phone, code, name }

class _SignInSheet extends StatefulWidget {
  const _SignInSheet();

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();

  _Step _step = _Step.phone;
  String? _verificationId;
  String? _channel;
  String? _registrationToken;
  bool _busy = false;
  bool _inBrowser = false;
  bool _googleFailed = false;
  bool _googlePending = false;
  String? _error;

  String get _org => sl<LocalStorage>().getOrgId() ?? ApiConstants.defaultOrgId;
  String get _e164 => '+91${_phone.text.trim().replaceAll(RegExp(r'\D'), '')}';

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  bool _validPhone() => _phone.text.trim().replaceAll(RegExp(r'\D'), '').length == 10;

  void _signInWithGoogle() {
    if (!_validPhone()) {
      setState(() => _error = trId('enter_a_valid_phone_number'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _inBrowser = false;
      _googleFailed = false;
    });
    context.read<AuthBloc>().add(AuthGoogleSignInRequested(
          organizationId: _org,
          phoneNumber: _e164,
        ));
  }

  void _sendOtpFallback() {
    if (!_validPhone()) {
      setState(() => _error = trId('enter_a_valid_phone_number'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _googleFailed = false;
    });
    context.read<AuthBloc>().add(
          AuthFirebasePnvRequested(organizationId: _org, phoneNumber: _e164),
        );
  }

  void _verify() {
    if (_code.text.trim().length != 6 || _verificationId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    context.read<AuthBloc>().add(AuthVerifyOtpRequested(
          verificationId: _verificationId!,
          otpCode: _code.text.trim(),
        ));
  }

  void _finish() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = trId('please_tell_us_your_name'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    context.read<AuthBloc>().add(AuthRegisterRequested(
          organizationId: _org,
          phoneNumber: _e164,
          registrationToken: _registrationToken ?? '',
          fullNameEn: _name.text.trim(),
          fullNameTa: _name.text.trim(),
          preferredLanguage: trLang(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthGoogleInBrowser) {
          setState(() => _inBrowser = true);
        } else if (state is AuthOtpSent) {
          setState(() {
            _busy = false;
            _verificationId = state.verificationId;
            _channel = state.channel;
            _step = _Step.code;
          });
        } else if (state is AuthNeedsRegistration) {
          setState(() {
            _busy = false;
            _registrationToken = state.registrationToken;
            _step = _Step.name;
          });
        } else if (state is AuthGoogleNeedsPhone) {
          setState(() {
            _busy = false;
            _name.text = state.fullName;
            _step = _Step.phone;
            _googlePending = true;
          });
          if (_validPhone()) {
            _sendOtpFallback();
          }
        } else if (state is AuthAuthenticated) {
          Navigator.of(context).pop(true);
        } else if (state is AuthFailureState) {
          ErrorReporter.instance.report(
            'sign-in failed at ${_step.name}: ${state.message}',
            null,
            context: 'auth/${_step.name}',
          );
          setState(() {
            _busy = false;
            _inBrowser = false;
            _error = state.message;
            _googleFailed = _step == _Step.phone;
          });
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(DSSpacing.lg, DSSpacing.md, DSSpacing.lg, DSSpacing.lg),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: EdgeInsets.only(bottom: DSSpacing.md),
                    decoration: BoxDecoration(
                      color: context.cBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(_title(), style: Theme.of(context).textTheme.headlineSmall),
                SizedBox(height: DSSpacing.xs),
                Text(
                  _subtitle(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.cTextSecondary),
                ),
                SizedBox(height: DSSpacing.lg),
                ..._fields(),
                if (_error != null) ...[
                  SizedBox(height: DSSpacing.sm),
                  Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                SizedBox(height: DSSpacing.lg),
                FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _busy ? null : _primaryAction,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_primaryLabel()),
                ),
                if (_step == _Step.phone && _googleFailed) ...[
                  SizedBox(height: DSSpacing.xs),
                  OutlinedButton(onPressed: _busy ? null : _sendOtpFallback, child: Text(trId('use_phone_otp_instead'))),
                ],
                if (_step == _Step.phone && _inBrowser) ...[
                  const SizedBox(height: 8),
                  Text(trId('google_finish_in_browser'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _busy = false;
                        _inBrowser = false;
                      });
                      context.read<AuthBloc>().add(const AuthGoogleSignInCancelled());
                    },
                    child: Text(trId('cancel')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title() => switch (_step) {
        _Step.phone => trId('sign_in_title'),
        _Step.code => trId('enter_the_code'),
        _Step.name => trId('what_should_we_call_you'),
      };

  String _subtitle() => switch (_step) {
        _Step.phone => trId('sign_in_subtitle'),
        _Step.code => switch (_channel) {
            'whatsapp' => trId('code_sent_whatsapp', {'phone': _e164}),
            'email' => trId('code_sent_email'),
            _ => trId('code_sent_to', {'phone': _e164}),
          },
        _Step.name => trId('name_only_the_rest_later'),
      };

  String _primaryLabel() => switch (_step) {
        _Step.phone => _googlePending ? trId('send_otp') : trId('sign_in'),
        _Step.code => trId('verify'),
        _Step.name => trId('done'),
      };

  void _primaryAction() => switch (_step) {
        _Step.phone => _googlePending ? _sendOtpFallback() : _signInWithGoogle(),
        _Step.code => _verify(),
        _Step.name => _finish(),
      };

  List<Widget> _fields() => switch (_step) {
        _Step.phone => [
            TextField(
              key: const ValueKey('sign-in-phone'),
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signInWithGoogle(),
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                prefixText: '+91  ',
                labelText: trId('phone_number'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        _Step.code => [
            TextField(
              key: const ValueKey('sign-in-code'),
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(fontSize: 22, letterSpacing: 8),
              textAlign: TextAlign.center,
              onChanged: (v) {
                if (v.length == 6) _verify();
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        _Step.name => [
            TextField(
              key: const ValueKey('sign-in-name'),
              controller: _name,
              autofocus: true,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _finish(),
              decoration: InputDecoration(
                labelText: trId('full_name'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
      };
}
