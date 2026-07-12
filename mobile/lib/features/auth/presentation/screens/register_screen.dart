import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/design_system/patterns/kolam_background.dart';
import '../../../../service_locator.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  final String organizationId;
  final String phoneNumber;
  // Pre-filled from Google sign-in (null for the OTP path). When phoneNumber is
  // empty (Google), the form shows an editable phone field to collect it.
  final String? prefillEmail;
  final String? prefillName;

  const RegisterScreen({
    super.key,
    required this.organizationId,
    required this.phoneNumber,
    this.prefillEmail,
    this.prefillName,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameTaCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime? _dob;
  String _role = 'PUBLIC_CITIZEN';

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Google sign-ups arrive without a verified phone — collect it in the form.
  /// OTP sign-ups already have a verified number, shown read-only.
  bool get _phoneEditable => widget.phoneNumber.trim().isEmpty;

  late AnimationController _aurora;

  @override
  void initState() {
    super.initState();
    // Pre-fill whatever Google gave us; the user completes the rest.
    _emailCtrl.text = widget.prefillEmail ?? '';
    _nameEnCtrl.text = widget.prefillName ?? '';
    _aurora = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _nameTaCtrl.dispose();
    _nameEnCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _aurora.dispose();
    super.dispose();
  }

  String _fmtDob(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: tr(en: 'Select date of birth', ta: 'பிறந்த தேதியைத் தேர்ந்தெடுக்கவும்'),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _submit() {
    final formOk = _formKey.currentState!.validate();
    if (_dob == null) {
      // A tap-to-pick field can't use a normal validator; surface it explicitly.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(
              en: 'Please select your date of birth',
              ta: 'உங்கள் பிறந்த தேதியைத் தேர்ந்தெடுக்கவும்')),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }
    if (!formOk) return;
    final lang = sl<LocalStorage>().getLang();
    final phone = _phoneEditable ? _phoneCtrl.text.trim() : widget.phoneNumber;
    context.read<AuthBloc>().add(AuthRegisterRequested(
          organizationId: widget.organizationId,
          phoneNumber: phone,
          email: _emailCtrl.text.trim(),
          dateOfBirth: _fmtDob(_dob!),
          role: _role,
          fullNameTa: _nameTaCtrl.text.trim(),
          fullNameEn: _nameEnCtrl.text.trim(),
          preferredLanguage: lang,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(ApiConstants.useAppShellV2 ? '/app' : '/home');
        } else if (state is AuthFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.accent),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBg,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
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
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F5132).withOpacity(0.52),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -60.0 + 80 * math.sin(t * 0.30 + 1.4),
                      top: 150.0 + 50 * math.cos(t * 0.45 + 0.7),
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF16A34A).withOpacity(0.28),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 40.0 + 60 * math.sin(t * 0.62 + 2.0),
                      bottom: 40.0 + 80 * math.cos(t * 0.42 + 1.5),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFD4AF37).withOpacity(0.07),
                        ),
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
          const KolamTextureLayer(color: Colors.white),

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
                            en: 'Join us in community service',
                            ta: 'சமூக சேவையில் இணைவோம்',
                            hi: 'सामुदायिक सेवा में हमसे जुड़ें',
                            ml: 'സാമൂഹിക സേവനത്തിൽ ഞങ്ങളോടൊപ്പം ചേരൂ',
                          ),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Glass card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.register,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (_phoneEditable)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: TextFormField(
                                          controller: _phoneCtrl,
                                          keyboardType: TextInputType.phone,
                                          autofillHints: const [AutofillHints.telephoneNumber],
                                          decoration: InputDecoration(
                                            label: Text(tr(en: 'Phone Number', ta: 'தொலைபேசி எண்', hi: 'फ़ोन नंबर', ml: 'ഫോൺ നമ്പർ')),
                                            hintText: '9876543210',
                                            prefixIcon: const Icon(Icons.phone_outlined),
                                          ),
                                          validator: (v) {
                                            final t = (v ?? '').replaceAll(RegExp(r'\s'), '');
                                            if (t.isEmpty) {
                                              return tr(en: 'Phone number is required', ta: 'தொலைபேசி எண் தேவை', hi: 'फ़ोन नंबर आवश्यक है', ml: 'ഫോൺ നമ്പർ ആവശ്യമാണ്');
                                            }
                                            final digits = t.replaceAll(RegExp(r'\D'), '');
                                            if (digits.length < 10) {
                                              return tr(en: 'Enter a valid phone number', ta: 'சரியான தொலைபேசி எண்ணை உள்ளிடவும்', hi: 'मान्य फ़ोन नंबर दर्ज करें', ml: 'സാധുവായ ഫോൺ നമ്പർ നൽകുക');
                                            }
                                            return null;
                                          },
                                        ),
                                      )
                                    else
                                      Text(
                                        widget.phoneNumber,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13),
                                      ),
                                    const SizedBox(height: 20),

                                    // Tamil name
                                    TextFormField(
                                      controller: _nameTaCtrl,
                                      decoration: InputDecoration(
                                        label: Text(l.nameInTamil),
                                        hintText: tr(
                                          en: 'e.g. Karthik J',
                                          ta: 'உதா: கார்த்திக் ஜே',
                                          hi: 'उदा. कार्तिक जे',
                                          ml: 'ഉദാ. കാർത്തിക് ജെ',
                                        ),
                                        prefixIcon: const Icon(Icons.person_outline),
                                      ),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty ? l.nameInTamil : null,
                                    ),
                                    const SizedBox(height: 16),

                                    // English name
                                    TextFormField(
                                      controller: _nameEnCtrl,
                                      decoration: InputDecoration(
                                        label: Text(l.nameInEnglish),
                                        hintText: tr(
                                          en: 'e.g. Karthik J',
                                          ta: 'எ.கா. Karthik J',
                                          hi: 'उदा. Karthik J',
                                          ml: 'ഉദാ. Karthik J',
                                        ),
                                        prefixIcon: const Icon(Icons.person_outline),
                                      ),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty ? l.nameInEnglish : null,
                                    ),
                                    const SizedBox(height: 16),

                                    // Email (mandatory)
                                    TextFormField(
                                      controller: _emailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [AutofillHints.email],
                                      decoration: InputDecoration(
                                        label: Text(tr(en: 'Email', ta: 'மின்னஞ்சல்', hi: 'ईमेल', ml: 'ഇമെയിൽ')),
                                        hintText: 'name@example.com',
                                        prefixIcon: const Icon(Icons.email_outlined),
                                      ),
                                      validator: (v) {
                                        final t = (v ?? '').trim();
                                        if (t.isEmpty) {
                                          return tr(en: 'Email is required', ta: 'மின்னஞ்சல் தேவை', hi: 'ईमेल आवश्यक है', ml: 'ഇമെയിൽ ആവശ്യമാണ്');
                                        }
                                        if (!_emailRe.hasMatch(t)) {
                                          return tr(en: 'Enter a valid email', ta: 'சரியான மின்னஞ்சலை உள்ளிடவும்', hi: 'मान्य ईमेल दर्ज करें', ml: 'സാധുവായ ഇമെയിൽ നൽകുക');
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Date of birth (mandatory) — tap to pick.
                                    InkWell(
                                      onTap: _pickDob,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          label: Text(tr(en: 'Date of Birth', ta: 'பிறந்த தேதி', hi: 'जन्म तिथि', ml: 'ജനന തീയതി')),
                                          prefixIcon: const Icon(Icons.cake_outlined),
                                        ),
                                        child: Text(
                                          _dob == null
                                              ? tr(en: 'Select your date of birth', ta: 'பிறந்த தேதியைத் தேர்ந்தெடுக்கவும்', hi: 'अपनी जन्म तिथि चुनें', ml: 'ജനന തീയതി തിരഞ്ഞെടുക്കുക')
                                              : _fmtDob(_dob!),
                                          style: TextStyle(
                                            color: _dob == null ? AppColors.textSecondary : AppColors.textPrimary,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Role selection
                                    Text(
                                      l.selectRole,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _RoleCard(
                                            icon: '🏠',
                                            label: l.citizen,
                                            subtitle: tr(
                                              en: 'Citizen',
                                              ta: 'குடிமகன்',
                                              hi: 'नागरिक',
                                              ml: 'പൗരൻ',
                                            ),
                                            isSelected: _role == 'PUBLIC_CITIZEN',
                                            onTap: () => setState(() => _role = 'PUBLIC_CITIZEN'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _RoleCard(
                                            icon: '🤝',
                                            label: l.volunteer,
                                            subtitle: tr(
                                              en: 'Volunteer',
                                              ta: 'தொண்டர்',
                                              hi: 'स्वयंसेवक',
                                              ml: 'സന്നദ്ധപ്രവർത്തകൻ',
                                            ),
                                            isSelected: _role == 'VOLUNTEER',
                                            onTap: () => setState(() => _role = 'VOLUNTEER'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),

                                    ElevatedButton(
                                      onPressed: isLoading ? null : _submit,
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                  color: Colors.white, strokeWidth: 2))
                                          : Text(l.register),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(l.alreadyHaveAccount,
                                            style: const TextStyle(
                                                color: AppColors.textSecondary)),
                                        TextButton(
                                          onPressed: () => context.go('/login'),
                                          child: Text(tr(
                                            en: 'Login',
                                            ta: 'உள்நுழைக',
                                            hi: 'लॉग इन',
                                            ml: 'ലോഗിൻ',
                                          )),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

class _RoleCard extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
