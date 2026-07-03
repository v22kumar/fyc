import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return s is AuthAuthenticated && s.user.isAdmin;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const OpportunityCreateScreen()),
    );
    if (created == true && mounted) {
      context.read<OpportunityBloc>().add(const OpportunityFetchRequested());
    }
  }

  static const _samples = [
    {
      'title': 'Tree Plantation Drive Volunteer',
      'org': 'FYC Green Team',
      'type': 'VOLUNTEER',
      'category': 'Environment',
      'location': 'Kanyakumari District',
      'desc': 'Help plant 500 trees across village schools. No experience needed.',
      'hours': '6 hrs',
    },
    {
      'title': 'Blood Donation Camp Helper',
      'org': 'FYC Blood Wing',
      'type': 'VOLUNTEER',
      'category': 'Healthcare',
      'location': 'Nagercoil',
      'desc': 'Assist in organizing our monthly blood donation camp.',
      'hours': '4 hrs',
    },
    {
      'title': 'Tamil Language Skill Exchange',
      'org': 'FYC Members',
      'type': 'SKILL',
      'category': 'Education',
      'location': 'Online',
      'desc': 'Exchange skills — teach what you know, learn what you need.',
      'hours': 'Flexible',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isTa = _lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'Opportunities & Skills', ta: 'வாய்ப்புகள் & பயிற்சி', hi: 'अवसर और कौशल', ml: 'അവസരങ്ങളും നൈപുണ്യങ്ങളും')),
      ),
      floatingActionButton: _canPost
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: Text(tr(en: 'Post', ta: 'பதிவிடு', hi: 'पोस्ट', ml: 'പോസ്റ്റ്')),
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

          final visibleSamples = _selectedTab == 'ALL'
              ? _samples
              : _samples.where((s) => s['type'] == _selectedTab).toList();

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
                    _FilterChip('VOLUNTEER', tr(en: 'Volunteer', ta: 'தன்னார்வ பணி', hi: 'स्वयंसेवक', ml: 'വളണ്ടിയർ'), _selectedTab, (v) => setState(() => _selectedTab = v)),
                    const SizedBox(width: 8),
                    _FilterChip('COURSE', tr(en: 'Courses', ta: 'பயிற்சிகள்', hi: 'पाठ्यक्रम', ml: 'കോഴ്സുകൾ'), _selectedTab, (v) => setState(() => _selectedTab = v)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    if (visibleSamples.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          tr(en: 'Sample Opportunities', ta: 'மாதிரி வாய்ப்புகள்', hi: 'नमूना अवसर', ml: 'സാമ്പിൾ അവസരങ്ങൾ'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.cTextSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      ...visibleSamples.map((s) => _SampleOpportunityCard(data: s, isTa: isTa)),
                    ],
                    if (filtered.isNotEmpty) ...[
                      if (visibleSamples.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                          child: Text(
                            tr(en: 'Available Opportunities', ta: 'கிடைக்கும் வாய்ப்புகள்', hi: 'उपलब्ध अवसर', ml: 'ലഭ്യമായ അവസരങ്ങൾ'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.cTextSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ...filtered.map((opp) => _OpportunityCard(opp: opp, isTa: isTa)),
                    ],
                    if (filtered.isEmpty)
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
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volunteer_activism, size: 48, color: Color(0xFF16A34A)),
          ),
          const SizedBox(height: 20),
          Text(
            tr(en: 'No Opportunities Yet', ta: 'வாய்ப்புகள் இல்லை', hi: 'अभी तक कोई अवसर नहीं', ml: 'ഇതുവരെ അവസരങ്ങളൊന്നുമില്ല'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.cText),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              tr(
                en: 'Be the first to post a volunteer opportunity or skill exchange for the FYC community.',
                ta: 'FYC சமூகத்திற்கு முதன்முதலில் தன்னார்வ வாய்ப்பை பதிவிடுங்கள்.',
                hi: 'FYC समुदाय के लिए स्वयंसेवक अवसर या कौशल विनिमय पोस्ट करने वाले पहले व्यक्ति बनें।',
                ml: 'FYC സമൂഹത്തിനായി ഒരു വളണ്ടിയർ അവസരമോ നൈപുണ്യ കൈമാറ്റമോ ആദ്യമായി പോസ്റ്റ് ചെയ്യൂ.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          if (onPost != null) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onPost,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F5132),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  tr(en: 'Post an Opportunity', ta: 'வாய்ப்பை பதிவிடவும்', hi: 'एक अवसर पोस्ट करें', ml: 'ഒരു അവസരം പോസ്റ്റ് ചെയ്യൂ'),
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

class _SampleOpportunityCard extends StatelessWidget {
  final Map<String, String> data;
  final bool isTa;
  const _SampleOpportunityCard({required this.data, required this.isTa});

  @override
  Widget build(BuildContext context) {
    final isVolunteer = data['type'] == 'VOLUNTEER';
    final typeColor = isVolunteer ? AppColors.primary : const Color(0xFF8B5CF6);

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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isVolunteer
                            ? tr(en: 'VOLUNTEERING', ta: 'தன்னார்வ பணி', hi: 'स्वयंसेवा', ml: 'വളണ്ടിയറിംഗ്')
                            : tr(en: 'SKILL EXCHANGE', ta: 'திறன் பரிமாற்றம்', hi: 'कौशल विनिमय', ml: 'നൈപുണ്യ കൈമാറ്റം'),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tr(en: 'Sample', ta: 'மாதிரி', hi: 'नमूना', ml: 'സാമ്പിൾ'),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.cTextSecondary),
                      ),
                    ),
                  ],
                ),
                if ((data['hours'] ?? '').isNotEmpty)
                  Text(
                    data['hours']!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data['title'] ?? '',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.cText),
            ),
            const SizedBox(height: 4),
            Text(
              '${data['org'] ?? ''} • ${data['category'] ?? ''}',
              style: TextStyle(fontSize: 12, color: context.cTextSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: context.cTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data['location'] ?? '',
                    style: TextStyle(fontSize: 12, color: context.cTextSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data['desc'] ?? '',
              style: TextStyle(fontSize: 13, color: context.cTextSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: typeColor.withOpacity(0.5),
                  disabledBackgroundColor: typeColor.withOpacity(0.5),
                  disabledForegroundColor: Colors.white,
                ),
                child: Text(
                  isVolunteer
                      ? tr(en: 'Apply to Volunteer', ta: 'தன்னார்வலராக விண்ணப்பி', hi: 'स्वयंसेवा के लिए आवेदन करें', ml: 'വളണ്ടിയർ ചെയ്യാൻ അപേക്ഷിക്കുക')
                      : tr(en: 'Exchange Skills', ta: 'திறன் பரிமாறவும்', hi: 'कौशल का आदान-प्रदान करें', ml: 'നൈപുണ്യങ്ങൾ കൈമാറുക'),
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

class _OpportunityCard extends StatelessWidget {
  final OpportunityEntity opp;
  final bool isTa;
  const _OpportunityCard({required this.opp, required this.isTa});

  @override
  Widget build(BuildContext context) {
    final isVolunteer = opp.type == 'VOLUNTEER';
    final typeColor = isVolunteer ? AppColors.primary : const Color(0xFF8B5CF6);

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
                        ? tr(en: 'VOLUNTEERING', ta: 'தன்னார்வ பணி', hi: 'स्वयंसेवा', ml: 'വളണ്ടിയറിംഗ്')
                        : tr(en: 'SKILL COURSE', ta: 'வகுப்பு', hi: 'कौशल पाठ्यक्रम', ml: 'നൈപുണ്യ കോഴ്സ്'),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                  ),
                ),
                if (opp.hours.isNotEmpty)
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
                      : tr(en: 'Enroll in Course', ta: 'வகுப்பில் சேரவும்', hi: 'पाठ्यक्रम में नामांकन करें', ml: 'കോഴ്സിൽ ചേരുക'),
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
