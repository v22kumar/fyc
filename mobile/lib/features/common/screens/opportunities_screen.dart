import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/local_storage.dart';
import '../../../service_locator.dart';
import '../../opportunities/domain/entities/opportunity_entity.dart';
import '../../opportunities/presentation/bloc/opportunity_bloc.dart';
import '../../opportunities/presentation/bloc/opportunity_event.dart';
import '../../opportunities/presentation/bloc/opportunity_state.dart';

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

  @override
  Widget build(BuildContext context) {
    final isTa = _lang == 'ta';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'வாய்ப்புகள் & பயிற்சி' : 'Opportunities & Skills'),
      ),
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
                        isTa
                            ? 'வெற்றி! விண்ணப்பம் சமர்ப்பிக்கப்பட்டது.'
                            : 'Success! Your application has been submitted.',
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
                    child: Text(isTa ? 'மீண்டும் முயற்சி' : 'Retry'),
                  ),
                ],
              ),
            );
          }

          final items = state is OpportunityLoaded ? state.opportunities : <OpportunityEntity>[];
          final filtered = _selectedTab == 'ALL'
              ? items
              : items.where((o) => o.type == _selectedTab).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _FilterChip('ALL', isTa ? 'அனைத்தும்' : 'All', _selectedTab, (v) => setState(() => _selectedTab = v)),
                    const SizedBox(width: 8),
                    _FilterChip('VOLUNTEER', isTa ? 'தன்னார்வ பணி' : 'Volunteer', _selectedTab, (v) => setState(() => _selectedTab = v)),
                    const SizedBox(width: 8),
                    _FilterChip('COURSE', isTa ? 'பயிற்சிகள்' : 'Courses', _selectedTab, (v) => setState(() => _selectedTab = v)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(isTa ? 'வாய்ப்புகள் ஏதுமில்லை' : 'No opportunities found'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) => _OpportunityCard(
                          opp: filtered[idx],
                          isTa: isTa,
                        ),
                      ),
              ),
            ],
          );
        },
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
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
                        ? (isTa ? 'தன்னார்வ பணி' : 'VOLUNTEERING')
                        : (isTa ? 'வகுப்பு' : 'SKILL COURSE'),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '${opp.displayOrganizer(isTa ? 'ta' : 'en')} • ${opp.displayCategory(isTa ? 'ta' : 'en')}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    opp.displayLocation(isTa ? 'ta' : 'en'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              opp.displayDescription(isTa ? 'ta' : 'en'),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
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
                      ? (isTa ? 'தன்னார்வலராக விண்ணப்பி' : 'Apply to Volunteer')
                      : (isTa ? 'வகுப்பில் சேரவும்' : 'Enroll in Course'),
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
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 1.5),
          boxShadow: isSelected ? AppTheme.cardShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
