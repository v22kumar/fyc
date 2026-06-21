import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../../../main.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = sl<LocalStorage>();

  static const _langs = [
    ('ta', 'அ', 'தமிழ்', 'Tamil', Color(0xFF0F5132)),
    ('en', 'A', 'English', 'English', Color(0xFF2563EB)),
    ('hi', 'अ', 'हिन्दी', 'Hindi', Color(0xFFDC2626)),
    ('ml', 'അ', 'മലയാളം', 'Malayalam', Color(0xFF7C3AED)),
  ];

  void _setTheme(String mode) {
    _storage.saveTheme(mode);
    themeModeNotifier.value = themeModeFromString(mode);
    setState(() {});
  }

  void _setLang(String code) {
    _storage.saveLang(code);
    localeNotifier.value = Locale(code);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = _storage.getTheme();
    final currentLang = _storage.getLang();

    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: context.cBackground,
        foregroundColor: context.cText,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('Appearance', context),
          const SizedBox(height: 10),
          _Card(
            context: context,
            child: Column(
              children: [
                _ThemeOption(label: 'Light', icon: Icons.light_mode, value: 'light', current: currentTheme, onTap: _setTheme),
                _Divider(context),
                _ThemeOption(label: 'Dark', icon: Icons.dark_mode, value: 'dark', current: currentTheme, onTap: _setTheme),
                _Divider(context),
                _ThemeOption(label: 'System Default', icon: Icons.settings_suggest, value: 'system', current: currentTheme, onTap: _setTheme),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Language', context),
          const SizedBox(height: 10),
          _Card(
            context: context,
            child: Column(
              children: [
                for (var i = 0; i < _langs.length; i++) ...[
                  if (i > 0) _Divider(context),
                  _LangOption(
                    code: _langs[i].$1,
                    letter: _langs[i].$2,
                    native: _langs[i].$3,
                    english: _langs[i].$4,
                    color: _langs[i].$5,
                    current: currentLang,
                    onTap: _setLang,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('More', context),
          const SizedBox(height: 10),
          _Card(
            context: context,
            child: Column(
              children: [
                _LinkRow(icon: Icons.info_outline, label: 'About FYC Connect', onTap: () => context.push('/about'), context: context),
                _Divider(context),
                _LinkRow(icon: Icons.shield_outlined, label: 'Privacy & Security', onTap: () {}, context: context),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _Card(
            context: context,
            child: _LinkRow(
              icon: Icons.logout,
              label: 'Logout',
              color: AppColors.accent,
              onTap: () {
                context.read<AuthBloc>().add(const AuthLogoutRequested());
                context.go('/login');
              },
              context: context,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('FYC Connect · v1.0.0',
                style: TextStyle(fontSize: 12, color: context.cTextSecondary)),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final BuildContext ctx;
  const _SectionLabel(this.text, this.ctx);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: context.cTextSecondary));
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final BuildContext context;
  const _Card({required this.child, required this.context});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cBorder),
      ),
      child: child,
    );
  }
}

Widget _Divider(BuildContext context) =>
    Divider(height: 1, thickness: 1, color: context.cBorder, indent: 56);

class _ThemeOption extends StatelessWidget {
  final String label, value, current;
  final IconData icon;
  final ValueChanged<String> onTap;
  const _ThemeOption({required this.label, required this.value, required this.current, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return ListTile(
      onTap: () => onTap(value),
      leading: Icon(icon, color: selected ? AppColors.primaryLight : context.cTextSecondary),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: context.cText)),
      trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primaryLight) : null,
    );
  }
}

class _LangOption extends StatelessWidget {
  final String code, letter, native, english, current;
  final Color color;
  final ValueChanged<String> onTap;
  const _LangOption({
    required this.code,
    required this.letter,
    required this.native,
    required this.english,
    required this.color,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == code;
    return ListTile(
      onTap: () => onTap(code),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withOpacity(0.14),
        child: Text(letter, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ),
      title: Text(native, style: TextStyle(fontWeight: FontWeight.w700, color: context.cText)),
      subtitle: Text(english, style: TextStyle(color: context.cTextSecondary, fontSize: 12)),
      trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primaryLight) : null,
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final BuildContext context;
  const _LinkRow({required this.icon, required this.label, required this.onTap, required this.context, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? context.cTextSecondary),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? context.cText)),
      trailing: color == null ? Icon(Icons.chevron_right, color: context.cTextSecondary) : null,
    );
  }
}
