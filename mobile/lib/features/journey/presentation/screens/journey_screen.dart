import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/journey_bloc.dart';
import '../../domain/entities/journey_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    context.read<JourneyBloc>().add(const JourneyFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'My Journey', ta: 'என் பயணம்', hi: 'मेरी यात्रा', ml: 'എന്റെ യാത്ര')),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.2],
          ),
        ),
        child: BlocBuilder<JourneyBloc, JourneyState>(
          builder: (context, state) {
            if (state is JourneyLoading || state is JourneyInitial) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            } else if (state is JourneyLoaded) {
              final j = state.journey;
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<JourneyBloc>().add(const JourneyFetchRequested());
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _ImpactCard(
                          icon: Icons.event,
                          color: Colors.purple,
                          title: tr(en: 'Events Attended', ta: 'நிகழ்வுகள்', hi: 'शामिल कार्यक्रम', ml: 'പങ്കെടുത്ത പരിപാടികൾ'),
                          value: j.eventsAttended.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.check_circle,
                          color: Colors.green,
                          title: tr(en: 'Issues Resolved', ta: 'புகார்கள்', hi: 'हल किए मुद्दे', ml: 'പരിഹരിച്ച പ്രശ്നങ്ങൾ'),
                          value: j.issuesHelped.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.park,
                          color: Colors.teal,
                          title: tr(en: 'Trees Planted', ta: 'மரங்கள்', hi: 'लगाए पेड़', ml: 'നട്ട മരങ്ങൾ'),
                          value: j.treesPlanted.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.water_drop,
                          color: Colors.redAccent,
                          title: tr(en: 'Blood Donations', ta: 'இரத்ததானம்', hi: 'रक्तदान', ml: 'രക്തദാനങ്ങൾ'),
                          value: j.bloodDonations.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.sports_soccer,
                          color: Colors.orange,
                          title: tr(en: 'Sports Matches', ta: 'விளையாட்டு', hi: 'खेल मैच', ml: 'കായിക മത്സരങ്ങൾ'),
                          value: j.sportsMatchesPlayed.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.timer,
                          color: Colors.blueAccent,
                          title: tr(en: 'Volunteer Hours', ta: 'நேரம்', hi: 'सेवा घंटे', ml: 'വൊളന്റിയർ മണിക്കൂറുകൾ'),
                          value: '${j.volunteerHours}h',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _MilestonesSection(j: j),
                  ],
                ),
              );
            } else if (state is JourneyFailure) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(state.message, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<JourneyBloc>().add(const JourneyFetchRequested());
                      },
                      child: Text(tr(en: 'Retry', ta: 'மீண்டும் முயற்சி', hi: 'पुनः प्रयास', ml: 'വീണ്ടും ശ്രമിക്കുക')),
                    )
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.background,
            child: Icon(Icons.emoji_events, size: 40, color: Colors.amber),
          ),
          const SizedBox(height: 16),
          Text(
            tr(en: 'Your Community Impact', ta: 'உங்கள் சமூகத் தாக்கம்', hi: 'आपका सामुदायिक प्रभाव', ml: 'നിങ്ങളുടെ സമൂഹ സ്വാധീനം'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            tr(en: 'Your contributions are making a real difference!', ta: 'உங்கள் பங்களிப்புகள் நமது சமூகத்தை மாற்றுகின்றன!', hi: 'आपके योगदान वास्तविक बदलाव ला रहे हैं!', ml: 'നിങ്ങളുടെ സംഭാവനകൾ യഥാർത്ഥ മാറ്റം വരുത്തുന്നു!'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _ImpactCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// Milestones — the "rewarding, not statistics" layer: badges that unlock as
/// the member contributes. Derived entirely from the journey stats (no backend
/// call), so locked badges gently show what's next.
class _MilestonesSection extends StatelessWidget {
  final JourneyEntity j;
  const _MilestonesSection({required this.j});

  @override
  Widget build(BuildContext context) {
    final total = j.eventsAttended +
        j.issuesHelped +
        j.bloodDonations +
        j.treesPlanted +
        j.sportsMatchesPlayed;
    final milestones = <_Milestone>[
      _Milestone(Icons.emoji_events_rounded,
          tr(en: 'First Steps', ta: 'முதல் அடி', hi: 'पहला कदम', ml: 'ആദ്യ ചുവട്'), total >= 1),
      _Milestone(Icons.event_available_rounded,
          tr(en: 'Event Regular', ta: 'நிகழ்வு வழக்கம்', hi: 'नियमित', ml: 'സ്ഥിരം'), j.eventsAttended >= 5),
      _Milestone(Icons.bloodtype_rounded,
          tr(en: 'Life Saver', ta: 'உயிர் காப்பாளர்', hi: 'जीवनरक्षक', ml: 'ജീവൻ രക്ഷകൻ'), j.bloodDonations >= 1),
      _Milestone(Icons.park_rounded,
          tr(en: 'Green Thumb', ta: 'பசுமைக் கரம்', hi: 'हरित', ml: 'ഹരിതം'), j.treesPlanted >= 5),
      _Milestone(Icons.timer_rounded,
          tr(en: 'Dedicated', ta: 'அர்ப்பணிப்பு', hi: 'समर्पित', ml: 'അർപ്പണം'), j.volunteerHours >= 25),
      _Milestone(Icons.verified_rounded,
          tr(en: 'Problem Solver', ta: 'தீர்வாளர்', hi: 'समाधानकर्ता', ml: 'പരിഹാരകൻ'), j.issuesHelped >= 3),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(en: 'Milestones', ta: 'மைல்கற்கள்', hi: 'उपलब्धियां', ml: 'നാഴികക്കല്ലുകൾ'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cText),
        ),
        const SizedBox(height: 4),
        Text(
          tr(
              en: 'Badges you unlock as you contribute.',
              ta: 'நீங்கள் பங்களிக்கும்போது திறக்கும் பதக்கங்கள்.',
              hi: 'योगदान करते ही अनलॉक होने वाले बैज।',
              ml: 'സംഭാവന ചെയ്യുമ്പോൾ അൺലോക്ക് ചെയ്യുന്ന ബാഡ്ജുകൾ.'),
          style: TextStyle(fontSize: 13, color: context.cTextSecondary),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final m in milestones) _MilestoneBadge(m: m)],
        ),
      ],
    );
  }
}

class _MilestoneBadge extends StatelessWidget {
  final _Milestone m;
  const _MilestoneBadge({required this.m});

  @override
  Widget build(BuildContext context) {
    final accent = m.unlocked ? AppColors.primary : context.cTextSecondary;
    return Opacity(
      opacity: m.unlocked ? 1 : 0.5,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: accent.withOpacity(m.unlocked ? 0.14 : 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: Icon(m.unlocked ? m.icon : Icons.lock_outline_rounded, color: accent, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              m.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.cText),
            ),
          ],
        ),
      ),
    );
  }
}

class _Milestone {
  final IconData icon;
  final String label;
  final bool unlocked;
  const _Milestone(this.icon, this.label, this.unlocked);
}
