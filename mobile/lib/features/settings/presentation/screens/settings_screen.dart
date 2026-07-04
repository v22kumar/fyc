import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/services/update_service.dart';
import '../../../../core/widgets/update_sheet.dart';
import '../../../../service_locator.dart';
import '../../../../core/services/device_profile_service.dart';
import '../../../../main.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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

  String _version = 'v1.0.0';
  bool _checking = false;
  bool _liteMode = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    // Reflect the user's manual preference — not currentTier, which can be
    // `lite` merely because of low battery / power-save mode.
    _liteMode = sl<DeviceProfileService>().manualLiteMode;
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = 'v${info.version} (${info.buildNumber})');
      }
    } catch (_) {/* keep default */}
  }

  Future<void> _checkForUpdates() async {
    if (_checking) return;
    final ta = _storage.getLang() == 'ta';
    setState(() => _checking = true);
    final update = await UpdateService.check();
    if (!mounted) return;
    setState(() => _checking = false);

    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ta
              ? 'நீங்கள் சமீபத்திய பதிப்பைப் பயன்படுத்துகிறீர்கள் ✅'
              : "You're on the latest version ✅"),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    // Polished sheet: in-app download progress + one-tap install.
    UpdateSheet.show(context, update);
  }

  void _showPrivacySheet() {
    final ta = _storage.getLang() == 'ta';
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    ta ? 'தனியுரிமை & பாதுகாப்பு' : 'Privacy & Security',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.cText),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                ta
                    ? 'FYC Connect உங்கள் பெயர், தொலைபேசி எண் மற்றும் சுயவிவரத் தகவல்களை உறுப்பினர் சேவைகளுக்காக மட்டுமே சேமிக்கிறது.\n\n'
                        '• உங்கள் தரவு மூன்றாம் தரப்பினருக்கு விற்கப்படுவதில்லை.\n'
                        '• இரத்த தான தொடர்பு விவரங்கள் நீங்கள் அனுமதித்தால் மட்டுமே காட்டப்படும்.\n'
                        '• உள்நுழைவு டோக்கன்கள் உங்கள் சாதனத்தில் பாதுகாப்பாக சேமிக்கப்படுகின்றன.\n'
                        '• உங்கள் கணக்கை நீக்க அல்லது தரவை அகற்ற நிர்வாகியை தொடர்பு கொள்ளவும்.'
                    : 'FYC Connect stores your name, phone number and profile details only to provide member services.\n\n'
                        '• Your data is never sold to third parties.\n'
                        '• Blood-donor contact details are shown only with your consent.\n'
                        '• Login tokens are stored securely on your device.\n'
                        '• To delete your account or data, contact the club admin.',
                style: TextStyle(fontSize: 13, height: 1.5, color: context.cTextSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(ta ? 'சரி' : 'OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLiteMode(bool value) async {
    final previous = _liteMode;
    setState(() => _liteMode = value);
    try {
      await sl<DeviceProfileService>().setManualLiteMode(value);
    } catch (_) {
      // Persistence failed — roll the switch back so the UI stays truthful.
      if (mounted) setState(() => _liteMode = previous);
    }
  }

  Future<void> _clearCache() async {
    // Basic cache clearing (e.g. image cache, network). Full Hive clearing in separate step.
    await DefaultCacheManager().emptyCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared'), backgroundColor: AppColors.primary),
    );
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
          _SectionLabel('Performance', context),
          const SizedBox(height: 10),
          _Card(
            context: context,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Lite Mode', style: TextStyle(fontWeight: FontWeight.w600, color: context.cText)),
                  subtitle: Text('Reduces data usage and disables autoplay', style: TextStyle(color: context.cTextSecondary, fontSize: 12)),
                  value: _liteMode,
                  onChanged: _toggleLiteMode,
                  activeColor: AppColors.primary,
                ),
                _Divider(context),
                _LinkRow(icon: Icons.cleaning_services, label: 'Clear Cache', onTap: _clearCache, context: context),
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
                _LinkRow(
                  icon: Icons.system_update,
                  label: _checking ? 'Checking for updates…' : 'Check for Updates',
                  onTap: _checkForUpdates,
                  context: context,
                ),
                _Divider(context),
                _LinkRow(icon: Icons.info_outline, label: 'About FYC Connect', onTap: () => context.push('/about'), context: context),
                _Divider(context),
                _LinkRow(icon: Icons.shield_outlined, label: 'Privacy & Security', onTap: _showPrivacySheet, context: context),
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
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to log out of your account?'),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.read<AuthBloc>().add(const AuthLogoutRequested());
                          context.go('/login');
                        },
                        child: const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              context: context,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('FYC Connect · $_version',
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
