import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../../service_locator.dart';
import '../../../membership/domain/entities/membership_entity.dart';
import '../../../membership/domain/usecases/get_my_card_usecase.dart';

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
                onTap: () => context.push('/members'),
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

class _ProfileCard extends StatefulWidget {
  final UserEntity? user;
  const _ProfileCard({required this.user});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  MembershipEntity? _card;
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    // Best-effort: enrich the card with Member ID / since / valid-till. Silent
    // on failure (a member without a card just sees name + role).
    sl<GetMyCardUseCase>()().then((res) {
      res.fold((_) {}, (card) {
        if (mounted) setState(() => _card = card);
      });
    }).catchError((_) {});
  }

  UserEntity? get user => widget.user;

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

  String _monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';
  String _dmy(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  Widget _line(String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(text,
            style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 11.5),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      );

  @override
  Widget build(BuildContext context) {
    final card = _card;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
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
                if (card != null) ...[
                  _line('${tr(en: 'Member ID', ta: 'உறுப்பினர் எண்', hi: 'सदस्य आईडी', ml: 'അംഗ ഐഡി')}: ${card.membershipNumber}'),
                  if (card.issuedAt != null)
                    _line('${tr(en: 'Member Since', ta: 'உறுப்பினரானது', hi: 'सदस्य से', ml: 'അംഗമായത്')}: ${_monthYear(card.issuedAt!)}'),
                ] else ...[
                  const SizedBox(height: 3),
                  Text(_roleLabel, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                  if (user?.phoneNumber != null) _line(user!.phoneNumber!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: QrImageView(
                  data: card?.qrCodePayload ?? user?.id ?? 'FYC',
                  version: QrVersions.auto,
                  size: 56,
                ),
              ),
              if (card != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${tr(en: 'Valid till', ta: 'செல்லுபடி', hi: 'मान्य', ml: 'സാധുത')} ${_dmy(card.expiresAt)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 8.5),
                ),
              ],
            ],
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
