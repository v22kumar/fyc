import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';

/// The Serve tab — the "do good / get help" bucket from the v2 mockup.
/// A row of quick actions (Blood · Report Issue · Volunteer) over a list of
/// emergency numbers. Theme-aware and 4-language; the SOS control lives in
/// the shell, not here.
///
/// "Opportunities" (business/service listings) deliberately does NOT live
/// here — Serve is civic service, not business networking. It's still
/// reachable via Home's Services sheet (route: /opportunities).
class ServeHubScreen extends StatelessWidget {
  const ServeHubScreen({super.key});

  static const _emergency = <_Emergency>[
    // 112 leads: it is India's unified emergency number — the one that still
    // works when a panicked person cannot remember which service they need.
    _Emergency(Icons.sos_rounded, Color(0xFFDC2626), '112',
        en: 'Any emergency', ta: 'எந்த அவசரமும்', hi: 'कोई भी आपातकाल',
        ml: 'ഏത് അടിയന്തരാവസ്ഥയും'),
    _Emergency(Icons.local_police_rounded, Color(0xFF2B4494), '100',
        en: 'Police', ta: 'காவல்துறை', hi: 'पुलिस', ml: 'പോലീസ്'),
    _Emergency(Icons.local_hospital_rounded, Color(0xFFE53935), '108',
        en: 'Ambulance', ta: 'ஆம்புலன்ஸ்', hi: 'एम्बुलेंस', ml: 'ആംബുലൻസ്'),
    _Emergency(Icons.local_fire_department_rounded, Color(0xFFF57C00), '101',
        en: 'Fire', ta: 'தீயணைப்பு', hi: 'अग्निशमन', ml: 'അഗ്നിശമനം'),
    _Emergency(Icons.bolt_rounded, Color(0xFFF59E0B), '1912',
        en: 'Electricity', ta: 'மின்சாரம்', hi: 'बिजली', ml: 'വൈദ്യുതി'),
    _Emergency(Icons.woman_rounded, Color(0xFF9333EA), '181',
        en: 'Women helpline', ta: 'மகளிர் உதவி எண்', hi: 'महिला हेल्पलाइन',
        ml: 'വനിതാ ഹെൽപ്പ്‌ലൈൻ'),
    _Emergency(Icons.child_care_rounded, Color(0xFF0891B2), '1098',
        en: 'Child helpline', ta: 'குழந்தைகள் உதவி எண்',
        hi: 'चाइल्ड हेल्पलाइन', ml: 'ചൈൽഡ് ഹെൽപ്പ്‌ലൈൻ'),
  ];

  Future<void> _dial(BuildContext context, String number) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: number);
    // On this page a dead call button is the worst possible silence: show
    // the number itself so a person can still dial it by hand.
    var placed = false;
    try {
      if (await canLaunchUrl(uri)) {
        placed = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      placed = false;
    }
    if (!placed) {
      messenger.showSnackBar(
        SnackBar(content: Text('${trId('could_not_open_dialer')}: $number')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cBackground,
        elevation: 0,
        centerTitle: false,
        title: Text(
          trId('serve_help'),
          style: TextStyle(color: context.cText, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── The app's own emergency feature, first ───────────────────────
          // A member in trouble opens the help page; the thing built exactly
          // for them must not hide behind a floating dot in the shell.
          const _SosCard(),
          const SizedBox(height: 24),
          // ── Quick actions ────────────────────────────────────────────────
          Row(
            children: [
              _Action(
                icon: Icons.bloodtype_rounded,
                tint: const Color(0xFFE53935),
                label: trId('blood'),
                sublabel: trId('donate_and_request'),
                onTap: () => context.push('/blood-donation'),
              ),
              _Action(
                icon: Icons.report_problem_rounded,
                tint: const Color(0xFFF59E0B),
                label: trId('report'),
                sublabel: trId('civic_complaint'),
                onTap: () => context.push('/issues'),
              ),
              _Action(
                icon: Icons.volunteer_activism_rounded,
                tint: const Color(0xFF14B891),
                label: trId('volunteer_4'),
                // Green FYC is where volunteering is a signup, not a
                // spectator list — '/events' answered a different question.
                sublabel: trId('drives_and_seva'),
                onTap: () => context.push('/green'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // ── Marketplace: two first-class peers ───────────────────────────
          Text(
            trId('marketplace'),
            style: TextStyle(color: context.cText, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          // ONE card, because /work is deliberately one directory (see
          // docs/work/01-architecture.md: "there is one kind of thing").
          // Two cards to the same screen promised two products that do not
          // exist — a member tapped both and landed in the same place.
          _PeerCard(
            icon: Icons.handyman_rounded,
            tint: const Color(0xFF14B891),
            title: trId('jobs_and_skills'),
            subtitle: trId('find_work_hire_skills'),
            onTap: () => context.push('/work'),
          ),
          const SizedBox(height: 28),
          // ── Emergency numbers ────────────────────────────────────────────
          Text(
            trId('emergency_numbers'),
            style: TextStyle(
              color: context.cText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.cBorder),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _emergency.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.cBorder),
                  _EmergencyRow(
                      item: _emergency[i],
                      onCall: () => _dial(context, _emergency[i].number)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;
  const _Action(
      {required this.icon,
      required this.tint,
      required this.label,
      this.sublabel,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: tint, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.cText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
              if (sublabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  sublabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: context.cTextSecondary, fontSize: 10.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PeerCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _PeerCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: tint, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(color: context.cText, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(color: context.cTextSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.cTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _EmergencyRow extends StatelessWidget {
  final _Emergency item;
  final VoidCallback onCall;
  const _EmergencyRow({required this.item, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onCall,
      leading: CircleAvatar(
        backgroundColor: item.tint.withValues(alpha: 0.12),
        child: Icon(item.icon, color: item.tint),
      ),
      title: Text(
        tr(en: item.en, ta: item.ta, hi: item.hi, ml: item.ml),
        style: TextStyle(color: context.cText, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.number,
            style: TextStyle(
              color: context.cText,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.call_rounded, color: item.tint, size: 20),
        ],
      ),
    );
  }
}

class _Emergency {
  final IconData icon;
  final Color tint;
  final String number;
  final String en, ta, hi, ml;
  const _Emergency(this.icon, this.tint, this.number,
      {required this.en, required this.ta, required this.hi, required this.ml});
}

/// The help page's headline: what SOS does and where it lives, in the
/// member's language, before any phone number.
class _SosCard extends StatelessWidget {
  const _SosCard();

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFDC2626);
    return InkWell(
      onTap: () => context.push('/sos'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: danger.withValues(alpha: context.isDark ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: danger.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: danger,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: danger.withValues(alpha: 0.35), blurRadius: 14),
                ],
              ),
              child: const Center(
                child: Text('SOS',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trId('emergency_q'),
                      style: TextStyle(
                          color: context.cText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    trId('sos_serve_explainer'),
                    style: TextStyle(
                        color: context.cTextSecondary,
                        fontSize: 12,
                        height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: context.cTextSecondary),
          ],
        ),
      ),
    );
  }
}
