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

/// One door, opened at the moment an action needs a name behind it.
///
/// What this replaces: a language screen, then a login screen with three doors
/// (phone, password, Google), then a registration form, then a "complete your
/// profile" form that asked for most of the same things again. Four screens
/// before the app, with the phone number typed three times.
///
/// The rearrangement is not cosmetic. **Identity is not a gate, it is a step in
/// an action.** Someone who installs this app can read the announcements, watch
/// a match, and see who has blood nearby without telling us anything. When they
/// reach for something that has their name on it — registering for an event,
/// offering to donate, posting — this comes up, they finish, and they land back
/// exactly where they were. The queue at the door is gone because there is no
/// door.
///
/// Google is not a separate path here. It is a *fill*: it supplies a name (and
/// on Android, via Credential Manager, the number) so the sheet is mostly
/// pre-answered. The number is still what identifies a member, because it is
/// the thing the club already knows people by.
///
/// Signing up asks for exactly one thing beyond the number: what to call you.
/// Date of birth, gender, blood group and area are wanted too — and they arrive
/// afterwards, one question every few days, through the profile prompts.
class SignInSheet {
  SignInSheet._();

  /// Whether we have a signed-in member, asking them to sign in if not.
  ///
  /// Returns false when they dismiss the sheet — which is an ordinary answer,
  /// not an error. The caller should simply not perform the action.
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
  // The sign-in has left for the browser. Different from _busy: there is
  // nothing here to wait for, and Google may never come back.
  bool _inBrowser = false;
  String? _error;

  String get _org => sl<LocalStorage>().getOrgId() ?? ApiConstants.defaultOrgId;

  /// India, because this is a club in Kanyakumari district and every member has
  /// a +91 number. Typed as a prefix rather than a picker: a country dropdown
  /// no member will ever change is a field they have to get past.
  String get _e164 => '+91${_phone.text.trim().replaceAll(RegExp(r'\D'), '')}';

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _sendCode() {
    if (_phone.text.trim().replaceAll(RegExp(r'\D'), '').length != 10) {
      setState(() => _error = trId('enter_a_valid_phone_number'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    context
        .read<AuthBloc>()
        .add(AuthSendOtpRequested(organizationId: _org, phoneNumber: _e164));
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
    // Everything not sent here is asked later, by the profile prompts.
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
          // Google gave us a name but not a verified number. Keep the name and
          // go back for the number — the number is what identifies a member.
          setState(() {
            _busy = false;
            _name.text = state.fullName;
            _step = _Step.phone;
          });
        } else if (state is AuthAuthenticated) {
          Navigator.of(context).pop(true);
        } else if (state is AuthFailureState) {
          // Report every sign-in failure, with the step it happened on.
          //
          // Both doors into this app went down after a deploy and there was no
          // way to tell why: a member sees "something went wrong", and nobody
          // can distinguish a TLS failure on an old handset from a 502 out of
          // Twilio from a null idToken caused by an unregistered signing key.
          // Each needs a different fix and they look identical from here.
          //
          // The reporter is the same one that already catches crashes, so this
          // costs nothing new and lands beside them.
          ErrorReporter.instance.report(
            'sign-in failed at ${_step.name}: ${state.message}',
            null,
            context: 'auth/${_step.name}',
          );
          setState(() {
            _busy = false;
            _inBrowser = false;
            _error = state.message;
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
          padding: EdgeInsets.fromLTRB(
              DSSpacing.lg, DSSpacing.md, DSSpacing.lg, DSSpacing.lg),
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
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: context.cTextSecondary),
                ),
                SizedBox(height: DSSpacing.lg),
                ..._fields(),
                if (_error != null) ...[
                  SizedBox(height: DSSpacing.sm),
                  Text(_error!,
                      style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                SizedBox(height: DSSpacing.lg),
                FilledButton(
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _busy ? null : _primaryAction,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_primaryLabel()),
                ),
                if (_step == _Step.phone) ...[
                  SizedBox(height: DSSpacing.xs),
                  // An accelerator, not an alternative. It fills the name (and
                  // on Android the number) so there is less to type — the
                  // number is still what gets verified.
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() => _busy = true);
                            context
                                .read<AuthBloc>()
                                .add(AuthGoogleSignInRequested(organizationId: _org));
                          },
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                    label: Text(trId('use_my_google_details')),
                  ),
                  if (_inBrowser) ...[
                    const SizedBox(height: 8),
                    Text(
                      trId('google_finish_in_browser'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _busy = false;
                          _inBrowser = false;
                        });
                        context
                            .read<AuthBloc>()
                            .add(const AuthGoogleSignInCancelled());
                      },
                      child: Text(trId('cancel')),
                    ),
                  ],
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
        // Named, because the server walks a ladder and the answer is not
        // knowable until it has been walked. "Check your messages" when the
        // code went to WhatsApp reads, from where the member is standing,
        // exactly like nothing being sent.
        _Step.code => switch (_channel) {
            'whatsapp' => trId('code_sent_whatsapp', {'phone': _e164}),
            'email' => trId('code_sent_email'),
            _ => trId('code_sent_to', {'phone': _e164}),
          },
        // Said plainly, because it is the reason there is no form here.
        _Step.name => trId('name_only_the_rest_later'),
      };

  String _primaryLabel() => switch (_step) {
        _Step.phone => trId('send_code'),
        _Step.code => trId('verify'),
        _Step.name => trId('done'),
      };

  void _primaryAction() => switch (_step) {
        _Step.phone => _sendCode(),
        _Step.code => _verify(),
        _Step.name => _finish(),
      };

  /// Every step's field carries its own key, and that is not decoration.
  ///
  /// All three steps put a `TextField` at the same position in the same list.
  /// Without a key Flutter matches them by type and position, reuses one
  /// element across all three, and keeps the open text-input connection —
  /// including the keyboard the *previous* step asked for. Phone and code are
  /// both numeric so nobody noticed, but the name step then opened a number pad
  /// and a member was asked to type their name on a keypad with no letters.
  ///
  /// Distinct keys force a fresh element per step, so each one configures the
  /// keyboard it actually wants. The explicit `keyboardType` on every field is
  /// the belt to that braces: never inherit an input type by accident.
  List<Widget> _fields() => switch (_step) {
        _Step.phone => [
            TextField(
              key: const ValueKey('sign-in-phone'),
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _sendCode(),
              // Lets Android offer the SIM's own number, so most members never
              // type it at all.
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
              // Android can read the code out of the SMS and fill this without
              // the member opening their messages.
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(fontSize: 22, letterSpacing: 8),
              textAlign: TextAlign.center,
              onChanged: (v) {
                // Six digits is the whole answer; making them press a button
                // afterwards is a step that exists only for the app's benefit.
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
              // A name is letters. Leaving this to the default meant inheriting
              // whatever the previous step opened, which was a number pad.
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
