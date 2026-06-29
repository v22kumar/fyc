import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

/// Profile hub: avatar, name, role, impact stats (from /users/me/journey) and
/// quick links to the user's activity + account actions. Read-only, reuses
/// existing routes; no new backend needed.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  int _events = 0, _donations = 0, _trees = 0;
  double _hours = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final res = await sl<ApiClient>().dio.get('/api/v1/users/me/journey');
      final d = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _events = (d['events_attended'] as num?)?.toInt() ?? 0;
        _donations = (d['blood_donations'] as num?)?.toInt() ?? 0;
        _trees = (d['trees_planted'] as num?)?.toInt() ?? 0;
        _hours = (d['volunteer_hours'] as num?)?.toDouble() ?? 0;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _prettyRole(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
      case 'ADMIN':
        return _lang == 'ta' ? 'நிர்வாகி' : 'Administrator';
      case 'EXECUTIVE_MEMBER':
        return _lang == 'ta' ? 'நிர்வாகக் குழு' : 'Executive Member';
      case 'CLUB_MEMBER':
        return _lang == 'ta' ? 'கிளப் உறுப்பினர்' : 'Club Member';
      case 'VOLUNTEER':
        return _lang == 'ta' ? 'தன்னார்வலர்' : 'Volunteer';
      default:
        return _lang == 'ta' ? 'உறுப்பினர்' : 'Member';
    }
  }

  void _confirmLogout() {
    final ta = _lang == 'ta';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(ta ? 'வெளியேறவா?' : 'Log out?'),
        content: Text(ta ? 'உங்கள் கணக்கிலிருந்து வெளியேற விரும்புகிறீர்களா?' : 'You will be signed out of your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ta ? 'ரத்து' : 'Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: Text(ta ? 'வெளியேறு' : 'Log out', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ta = _lang == 'ta';
    final state = context.watch<AuthBloc>().state;
    String name = ta ? 'FYC உறுப்பினர்' : 'FYC Member';
    String role = 'MEMBER';
    if (state is AuthAuthenticated) {
      name = (ta
              ? (state.user.fullNameTa ?? state.user.fullNameEn)
              : (state.user.fullNameEn ?? state.user.fullNameTa)) ??
          name;
      role = state.user.role;
    }
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(ta ? 'சுயவிவரம்' : 'Profile',
            style: TextStyle(color: context.cText, fontWeight: FontWeight.w800, fontSize: 18)),
        iconTheme: IconThemeData(color: context.cText),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // ── Header card (gradient, avatar, name, role) ───────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B6E4F), Color(0xFF12A150)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: const Color(0xFF12A150).withOpacity(0.30), blurRadius: 18, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_prettyRole(role),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Stats row ────────────────────────────────────────────────────
          Row(
            children: [
              _stat(context, _events.toString(), ta ? 'நிகழ்வுகள்' : 'Events', Icons.event, const Color(0xFF8B5CF6)),
              const SizedBox(width: 10),
              _stat(context, _hours.toStringAsFixed(0), ta ? 'மணி' : 'Hours', Icons.schedule, const Color(0xFF2563EB)),
              const SizedBox(width: 10),
              _stat(context, _donations.toString(), ta ? 'தானம்' : 'Donations', Icons.water_drop, const Color(0xFFEF4444)),
              const SizedBox(width: 10),
              _stat(context, _trees.toString(), ta ? 'மரங்கள்' : 'Trees', Icons.eco, const Color(0xFF16A34A)),
            ],
          ),
          const SizedBox(height: 22),
          // ── Activity ─────────────────────────────────────────────────────
          _sectionLabel(context, ta ? 'என் செயல்பாடு' : 'My Activity'),
          _menuTile(context, Icons.map_rounded, ta ? 'என் பயணம்' : 'My Journey', const Color(0xFFEC4899), () => context.push('/journey')),
          _menuTile(context, Icons.celebration_rounded, ta ? 'என் நிகழ்வுகள்' : 'My Events', const Color(0xFF8B5CF6), () => context.push('/events')),
          _menuTile(context, Icons.search_rounded, ta ? 'என் புகார்கள்' : 'My Reports', const Color(0xFF14B8A6), () => context.push('/issues/track')),
          _menuTile(context, Icons.badge_rounded, ta ? 'என் அட்டை' : 'Membership Card', const Color(0xFF0B6E4F), () => context.push('/membership')),
          const SizedBox(height: 18),
          // ── Account ──────────────────────────────────────────────────────
          _sectionLabel(context, ta ? 'கணக்கு' : 'Account'),
          _menuTile(context, Icons.settings_rounded, ta ? 'அமைப்புகள்' : 'Settings', const Color(0xFF475569), () => context.push('/settings')),
          _menuTile(context, Icons.info_outline_rounded, ta ? 'எங்களைப் பற்றி' : 'About FYC', const Color(0xFF475569), () => context.push('/about')),
          const SizedBox(height: 18),
          // ── Logout ───────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.accent),
              label: Text(ta ? 'வெளியேறு' : 'Log out',
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (!_loaded) const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBorder),
          boxShadow: context.isDark ? null : AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cText)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: context.cTextSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(text,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.cTextSecondary, letterSpacing: 0.3)),
      );

  Widget _menuTile(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: color.withOpacity(context.isDark ? 0.22 : 0.12), borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: context.cText))),
                Icon(Icons.chevron_right_rounded, color: context.cTextSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
