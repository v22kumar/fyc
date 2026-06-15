import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  final String organizationId;
  final String phoneNumber;

  const RegisterScreen({
    super.key,
    required this.organizationId,
    required this.phoneNumber,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameTaCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  String _role = 'PUBLIC_CITIZEN';

  @override
  void dispose() {
    _nameTaCtrl.dispose();
    _nameEnCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final lang = sl<LocalStorage>().getLang();
    context.read<AuthBloc>().add(AuthRegisterRequested(
          organizationId: widget.organizationId,
          phoneNumber: widget.phoneNumber,
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
          context.go('/home');
        } else if (state is AuthFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.accent),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.register)),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.paddingPage),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      l.register,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.phoneNumber,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 28),

                    // Tamil name
                    TextFormField(
                      controller: _nameTaCtrl,
                      decoration: InputDecoration(
                        label: Text(l.nameInTamil),
                        hintText: 'உதா: கார்த்திக் ஜே',
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
                        hintText: 'e.g. Karthik J',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l.nameInEnglish : null,
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
                            subtitle: 'குடிமகன்',
                            isSelected: _role == 'PUBLIC_CITIZEN',
                            onTap: () => setState(() => _role = 'PUBLIC_CITIZEN'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleCard(
                            icon: '🤝',
                            label: l.volunteer,
                            subtitle: 'தொண்டர்',
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
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(l.register),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l.alreadyHaveAccount,
                            style: const TextStyle(color: AppColors.textSecondary)),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(sl<LocalStorage>().getLang() == 'ta' ? 'உள்நுழைக' : 'Login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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
