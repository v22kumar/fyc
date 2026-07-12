import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/local_storage.dart';
import '../../../service_locator.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../../opportunities/domain/entities/opportunity_entity.dart';
import '../../opportunities/presentation/bloc/opportunity_bloc.dart';
import '../../opportunities/presentation/bloc/opportunity_event.dart';
import '../../opportunities/presentation/bloc/opportunity_state.dart';
import '../../opportunities/presentation/screens/opportunity_create_screen.dart';

class OpportunitiesScreen extends StatelessWidget {
  const OpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OpportunityBloc>()..add(const OpportunityFetchRequested()),
      child: const _OpportunitiesView(),
    );
  }
}

class _OpportunitiesView extends StatefulWidget {
  const _OpportunitiesView();

  @override
  State<_OpportunitiesView> createState() => _OpportunitiesViewState();
}

class _OpportunitiesViewState extends State<_OpportunitiesView> {
  String get _lang => sl<LocalStorage>().getLang();
  String _selectedTab = 'ALL';

  bool get _canPost {
    final s = context.read<AuthBloc>().state;
    // A member marketplace: any signed-in member (CLUB_MEMBER+) can post.
    return s is AuthAuthenticated && s.user.isMember;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const OpportunityCreateScreen()),
    );
    if (created == true && mounted) {
      context.read<OpportunityBloc>().add(const OpportunityFetchRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTa = _lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'Jobs & Gigs', ta: 'வேலைகள் & பணிகள்', hi: 'नौकरियाँ और काम', ml: 'ജോലികളും ഗിഗുകളും')),
      ),
      floatingActionButton: _canPost
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: Text(tr(en: 'Post a Job', ta: 'வேலை பதிவிடு', hi: 'नौकरी पोस्ट करें', ml: 'ജോലി പോസ്റ്റ്')),
            )
          : null,
      body: BlocConsumer<OpportunityBloc, OpportunityState>(
        listener: (context, state) {
          if (state is OpportunityApplySuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(
                          en: 'Success! Your application has been submitted.',
                          ta: 'வெற்றி! விண்ணப்பம் சமர்ப்பிக்கப்பட்டது.',
                          hi: 'सफलता! आपका आवेदन सबमिट कर दिया गया है।',
                          ml: 'വിജയം! നിങ്ങളുടെ അപേക്ഷ സമർപ്പിച്ചു.',
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
          if (state is OpportunityFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.accent),
            );
          }
        },
        builder: (context, state) {
          if (state is OpportunityLoading || state is OpportunityInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is OpportunityFailure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.read<OpportunityBloc>().add(const OpportunityFetchRequested()),
                    child: Text(tr(en: 'Retry', ta: 'மீண்டும் முயற்சி', hi: 'फिर से प्रयास करें', ml: 'വീണ്ടും ശ്രമിക്കുക')),
                  ),
                ],
              ),
            );
          }

          final items = state is OpportunityLoaded ? state.opportunities : <OpportunityEntity>[];
          final filtered = _selectedTab == 'ALL'
              ? items
              : items.where((o) => o.type == _selectedTab).toList();

          return RefreshIndicator(
            onRefresh: () async => context.read<OpportunityBloc>().add(const OpportunityFetchRequested()),
            child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _FilterChip('ALL', tr(en: 'All', ta: 'அனைத்தும்', hi: 'सभी', ml: 'എല്ലാം'), _selectedTab, (v) => setState(() => _selectedTab = v)),
                    const SizedBox(width: 8),
                    _FilterChip('JOB', tr(en: 'Jobs', ta: 'வேலைகள்', hi: 'नौकरियाँ', ml: 'ജോലികൾ'), _selectedTab, (v) => setState(() => _selectedTab = v)),
                    const SizedBox(width: 8),
                    _FilterChip('VOLUNTEER', tr(en: 'Volunteer', ta: 'தன்னார்வ பணி', hi: 'स्वयंसेवक', ml: 'വളണ്ടിയർ'), _selectedTab, (v) => setState(() => _selectedTab = v)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    // Skills Directory is the marketplace's supply side — a
                    // first-class peer, not a buried link. "Hiring? Browse the
                    // people offering skills."
                    _SkillsPeerLink(onTap: () => context.push('/community')),
                    const SizedBox(height: 14),
                    if (filtered.isNotEmpty)
                      ...filtered.map((opp) => _OpportunityCard(opp: opp, isTa: isTa))
                    else
                      _PremiumEmptyState(isTa: isTa, onPost: _canPost ? _openCreate : null),
                  ],
                ),
              ),
            ],
            ),
          );
        },
      ),
    );
  }
}

class _PremiumEmptyState extends StatelessWidget {
  final bool isTa;
  final VoidCallback? onPost;
  const _PremiumEmptyState({required this.isTa, this.onPost});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.work_outline_rounded, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            tr(en: 'No Jobs Yet', ta: 'வேலைகள் இல்லை', hi: 'अभी तक कोई नौकरी नहीं', ml: 'ഇതുവരെ ജോലികളൊന്നുമില്ല'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.cText),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              tr(
                en: 'Be the first to post a job or volunteer drive for the FYC community.',
                ta: 'FYC சமூகத்திற்கு முதன்முதலில் வேலை அல்லது தன்னார்வப் பணியை பதிவிடுங்கள்.',
                hi: 'FYC समुदाय के लिए नौकरी या स्वयंसेवक अभियान पोस्ट करने वाले पहले व्यक्ति बनें।',
                ml: 'FYC സമൂഹത്തിനായി ഒരു ജോലിയോ വളണ്ടിയർ ഡ്രൈവോ ആദ്യമായി പോസ്റ്റ് ചെയ്യൂ.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.cTextSecondary),
            ),
          ),
          if (onPost != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onPost,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  tr(en: 'Post a Job', ta: 'வேலை பதிவிடு', hi: 'नौकरी पोस्ट करें', ml: 'ജോലി പോസ്റ്റ് ചെയ്യൂ'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Skills Directory peer — the supply side of the marketplace. Members
/// browse people offering a skill (carpenters, electricians, tutors) to hire.
class _SkillsPeerLink extends StatelessWidget {
  final VoidCallback onTap;
  const _SkillsPeerLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.handyman_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(en: 'Skills Directory', ta: 'திறன் அடைவு', hi: 'कौशल निर्देशिका', ml: 'നൈപുണ്യ ഡയറക്ടറി'),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.cText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr(en: 'Hiring? Browse carpenters, electricians, tutors & more',
                        ta: 'தச்சர், மின்சாரி, ஆசிரியர் & பலரை பாருங்கள்',
                        hi: 'बढ़ई, इलेक्ट्रीशियन, शिक्षक और अधिक देखें',
                        ml: 'ആശാരി, ഇലക്ട്രീഷ്യൻ, ട്യൂട്ടർ എന്നിവരെ കാണൂ'),
                    style: TextStyle(fontSize: 12.5, color: context.cTextSecondary),
                  ),
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

class _OpportunityCard extends StatelessWidget {
  final OpportunityEntity opp;
  final bool isTa;
  const _OpportunityCard({required this.opp, required this.isTa});

  @override
  Widget build(BuildContext context) {
    final isVolunteer = opp.isVolunteer;
    final typeColor = isVolunteer ? AppColors.primaryLight : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: context.cBorder),
        boxShadow: context.isDark ? null : AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isVolunteer
                        ? tr(en: 'VOLUNTEER', ta: 'தன்னார்வ பணி', hi: 'स्वयंसेवा', ml: 'വളണ്ടിയർ')
                        : tr(en: 'JOB', ta: 'வேலை', hi: 'नौकरी', ml: 'ജോലി'),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                  ),
                ),
                if (opp.budget.isNotEmpty)
                  Text(
                    opp.budget,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                  )
                else if (isVolunteer)
                  Text(
                    tr(en: 'Volunteer', ta: 'தன்னார்வம்', hi: 'स्वयंसेवा', ml: 'വളണ്ടിയർ'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryLight),
                  )
                else if (opp.hours.isNotEmpty)
                  Text(
                    opp.hours,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              opp.displayTitle(isTa ? 'ta' : 'en'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.cText),
            ),
            const SizedBox(height: 4),
            Text(
              '${opp.displayOrganizer(isTa ? 'ta' : 'en')} • ${opp.displayCategory(isTa ? 'ta' : 'en')}',
              style: TextStyle(fontSize: 12, color: context.cTextSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: context.cTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    opp.displayLocation(isTa ? 'ta' : 'en'),
                    style: TextStyle(fontSize: 12, color: context.cTextSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              opp.displayDescription(isTa ? 'ta' : 'en'),
              style: TextStyle(fontSize: 13, color: context.cTextSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => context.read<OpportunityBloc>().add(
                      OpportunityApplyRequested(id: opp.id, title: opp.displayTitle(isTa ? 'ta' : 'en')),
                    ),
                style: ElevatedButton.styleFrom(backgroundColor: typeColor),
                child: Text(
                  isVolunteer
                      ? tr(en: 'Apply to Volunteer', ta: 'தன்னார்வலராக விண்ணப்பி', hi: 'स्वयंसेवा के लिए आवेदन करें', ml: 'വളണ്ടിയർ ചെയ്യാൻ അപേക്ഷിക്കുക')
                      : tr(en: 'Apply Now', ta: 'இப்போது விண்ணப்பி', hi: 'अभी आवेदन करें', ml: 'ഇപ്പോൾ അപേക്ഷിക്കൂ'),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String value;
  final String label;
  final String selected;
  final ValueChanged<String> onTap;
  const _FilterChip(this.value, this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.cSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppColors.primary : context.cBorder, width: 1.5),
          boxShadow: isSelected && !context.isDark ? AppTheme.cardShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.cText,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
