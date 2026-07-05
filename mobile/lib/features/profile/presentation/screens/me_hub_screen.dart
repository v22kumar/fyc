import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/entities/user_entity.dart';

/// The Me tab — identity hub per the v2 mockup: a profile/QR card over a list
/// of account destinations. Theme-aware + 4-language.
class MeHubScreen extends StatelessWidget {
  const MeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cBackground,
        elevation: 0,
        title: Text(
          '${tr(en: 'Me', ta: 'என்', hi: 'मैं', ml: 'ഞാൻ')} ',
          style: TextStyle(color: context.cText, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: context.cText),
            onPressed: () => context.push('/settings'),
            tooltip: tr(en: 'Settings', ta: 'அமைப்புகள்'),
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final user = state is AuthAuthenticated ? state.user : null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _ProfileCard(user: user),
              const SizedBox(height: 20),
              _MeTile(
                icon: Icons.person_rounded,
                label: tr(en: 'My Profile', ta: 'என் சுயவிவரம்', hi: 'मेरी प्रोफ़ाइल', ml: 'എന്റെ പ്രൊഫൈൽ'),
                onTap: () => context.push('/profile'),
              ),
              _MeTile(
                icon: Icons.badge_rounded,
                label: tr(en: 'Membership Card', ta: 'உறுப்பினர் அட்டை', hi: 'सदस्यता कार्ड', ml: 'അംഗത്വ കാർഡ്'),
                onTap: () => context.push('/membership'),
              ),
              _MeTile(
                icon: Icons.groups_rounded,
                label: tr(en: 'Member Directory', ta: 'உறுப்பினர் பட்டியல்', hi: 'सदस्य निर्देशिका', ml: 'അംഗ ഡയറക്ടറി'),
                onTap: () => context.push('/directory'),
              ),
              _MeTile(
                icon: Icons.event_available_rounded,
                label: tr(en: 'My Event Registrations', ta: 'என் நிகழ்வு பதிவுகள்', hi: 'मेरे इवेंट पंजीकरण', ml: 'എന്റെ ഇവന്റ് രജിസ്ട്രേഷനുകൾ'),
                onTap: () => context.push('/events'),
              ),
              _MeTile(
                icon: Icons.settings_rounded,
                label: tr(en: 'Settings', ta: 'அமைப்புகள்', hi: 'सेटिंग्स', ml: 'ക്രമീകരണങ്ങൾ'),
                onTap: () => context.push('/settings'),
              ),
              _MeTile(
                icon: Icons.help_outline_rounded,
                label: tr(en: 'Help & Support', ta: 'உதவி & ஆதரவு', hi: 'सहायता और समर्थन', ml: 'സഹായം & പിന്തുണ'),
                onTap: () => context.push('/about'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserEntity? user;
  const _ProfileCard({required this.user});

  String get _name => user?.fullNameEn ?? user?.fullNameTa ?? 'FYC Member';
  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    final letters = parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join();
    return letters.isEmpty ? 'F' : letters.toUpperCase();
  }

  String get _roleLabel {
    if (user == null) return '';
    if (user!.isAdmin) return tr(en: 'Club Official', ta: 'கழக அதிகாரி');
    if (user!.isVolunteer) return tr(en: 'Volunteer', ta: 'தொண்டர்');
    return tr(en: 'Member', ta: 'உறுப்பினர்');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5132), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _roleLabel,
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
                if (user?.phoneNumber != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user!.phoneNumber!,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (user != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: user!.id,
                version: QrVersions.auto,
                size: 60,
              ),
            ),
        ],
      ),
    );
  }
}

class _MeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MeTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cBorder),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: context.cText, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.cTextSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
