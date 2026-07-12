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
    _Emergency(Icons.local_police_rounded, Color(0xFF2B4494), '100',
        en: 'Police', ta: 'காவல்துறை', hi: 'पुलिस', ml: 'പോലീസ്'),
    _Emergency(Icons.local_hospital_rounded, Color(0xFFE53935), '108',
        en: 'Ambulance', ta: 'ஆம்புலன்ஸ்', hi: 'एम्बुलेंस', ml: 'ആംബുലൻസ്'),
    _Emergency(Icons.local_fire_department_rounded, Color(0xFFF57C00), '101',
        en: 'Fire', ta: 'தீயணைப்பு', hi: 'अग्निशमन', ml: 'അഗ്നിശമനം'),
    _Emergency(Icons.bolt_rounded, Color(0xFFF59E0B), '1912',
        en: 'Electricity', ta: 'மின்சாரம்', hi: 'बिजली', ml: 'വൈദ്യുതി'),
  ];

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          tr(en: 'Serve / Help', ta: 'சேவை / உதவி', hi: 'सेवा / मदद', ml: 'സേവനം / സഹായം'),
          style: TextStyle(color: context.cText, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── Quick actions ────────────────────────────────────────────────
          Row(
            children: [
              _Action(
                icon: Icons.bloodtype_rounded,
                tint: const Color(0xFFE53935),
                label: tr(en: 'Blood', ta: 'இரத்தம்', hi: 'रक्त', ml: 'രക്തം'),
                onTap: () => context.push('/blood-donation'),
              ),
              _Action(
                icon: Icons.report_problem_rounded,
                tint: const Color(0xFFF59E0B),
                label: tr(en: 'Report', ta: 'புகார்', hi: 'शिकायत', ml: 'റിപ്പോർട്ട്'),
                onTap: () => context.push('/issues'),
              ),
              _Action(
                icon: Icons.volunteer_activism_rounded,
                tint: const Color(0xFF14B891),
                label: tr(en: 'Volunteer', ta: 'தொண்டு', hi: 'स्वयंसेवक', ml: 'സന്നദ്ധം'),
                onTap: () => context.push('/events'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // ── Marketplace: two first-class peers ───────────────────────────
          Text(
            tr(en: 'Marketplace', ta: 'சந்தை', hi: 'बाज़ार', ml: 'മാർക്കറ്റ്'),
            style: TextStyle(color: context.cText, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _PeerCard(
            icon: Icons.work_rounded,
            tint: const Color(0xFF16255A),
            title: tr(en: 'Jobs & Gigs', ta: 'வேலைகள் & பணிகள்', hi: 'नौकरियाँ और काम', ml: 'ജോലികളും ഗിഗുകളും'),
            subtitle: tr(en: 'Find work · post a job', ta: 'வேலை தேடு · பதிவிடு',
                hi: 'काम खोजें · नौकरी पोस्ट करें', ml: 'ജോലി കണ്ടെത്തൂ · പോസ്റ്റ് ചെയ്യൂ'),
            onTap: () => context.push('/opportunities'),
          ),
          const SizedBox(height: 12),
          _PeerCard(
            icon: Icons.handyman_rounded,
            tint: const Color(0xFF14B891),
            title: tr(en: 'Skills Directory', ta: 'திறன் அடைவு', hi: 'कौशल निर्देशिका', ml: 'നൈപുണ്യ ഡയറക്ടറി'),
            subtitle: tr(en: 'Hire local skills · offer yours', ta: 'திறன்களை பாருங்கள் · வழங்குங்கள்',
                hi: 'स्थानीय कौशल किराए पर लें', ml: 'പ്രാദേശിക നൈപുണ്യം · നിങ്ങളുടേത് നൽകൂ'),
            onTap: () => context.push('/community'),
          ),
          const SizedBox(height: 28),
          // ── Emergency numbers ────────────────────────────────────────────
          Text(
            tr(en: 'Emergency Numbers', ta: 'அவசர எண்கள்', hi: 'आपातकालीन नंबर', ml: 'അടിയന്തര നമ്പറുകൾ'),
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
                  _EmergencyRow(item: _emergency[i], onCall: () => _dial(_emergency[i].number)),
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
  final VoidCallback onTap;
  const _Action({required this.icon, required this.tint, required this.label, required this.onTap});

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
                  color: tint.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: tint, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.cTextSecondary, fontSize: 12),
              ),
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
                color: tint.withOpacity(0.12),
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
        backgroundColor: item.tint.withOpacity(0.12),
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
