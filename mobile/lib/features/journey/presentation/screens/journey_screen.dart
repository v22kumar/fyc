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
        title: Text(trId('my_journey')),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.background],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.2],
          ),
        ),
        child: BlocBuilder<JourneyBloc, JourneyState>(
          builder: (context, state) {
            if (state is JourneyLoading || state is JourneyInitial) {
              return Center(child: CircularProgressIndicator(color: AppColors.background));
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
                          title: trId('events_attended'),
                          value: j.eventsAttended.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.check_circle,
                          color: AppColors.success,
                          title: trId('issues_resolved'),
                          value: j.issuesHelped.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.park,
                          color: Colors.teal,
                          title: trId('trees_planted'),
                          value: j.treesPlanted.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.water_drop,
                          color: AppColors.danger,
                          title: trId('blood_donations'),
                          value: j.bloodDonations.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.sports_soccer,
                          color: AppColors.warning,
                          title: trId('sports_matches'),
                          value: j.sportsMatchesPlayed.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.timer,
                          color: AppColors.info,
                          title: trId('volunteer_hours'),
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
                    Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 16),
                    Text(state.message, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<JourneyBloc>().add(const JourneyFetchRequested());
                      },
                      child: Text(trId('retry_4')),
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
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
            child: Icon(Icons.emoji_events, size: 40, color: AppColors.warning),
          ),
          const SizedBox(height: 16),
          Text(
            trId('your_community_impact'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            trId('your_contributions_are_making_a_real_dif'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary[600]),
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
        color: AppColors.background,
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
              color: AppColors.textSecondary[600],
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
          trId('first_steps'), total >= 1),
      _Milestone(Icons.event_available_rounded,
          trId('event_regular'), j.eventsAttended >= 5),
      _Milestone(Icons.bloodtype_rounded,
          trId('life_saver'), j.bloodDonations >= 1),
      _Milestone(Icons.park_rounded,
          trId('green_thumb'), j.treesPlanted >= 5),
      _Milestone(Icons.timer_rounded,
          trId('dedicated'), j.volunteerHours >= 25),
      _Milestone(Icons.verified_rounded,
          trId('problem_solver'), j.issuesHelped >= 3),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trId('milestones'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cText),
        ),
        const SizedBox(height: 4),
        Text(
          trId('badges_you_unlock_as_you_contribute'),
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
