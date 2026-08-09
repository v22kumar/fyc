import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/community_profile_entity.dart';
import '../bloc/community_bloc.dart';
import '../bloc/community_event.dart';
import '../bloc/community_state.dart';
import '../../../../core/design_system/components/ds_skeleton.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class CommunityDirectoryScreen extends StatefulWidget {
  const CommunityDirectoryScreen({super.key});

  @override
  State<CommunityDirectoryScreen> createState() =>
      _CommunityDirectoryScreenState();
}

class _CommunityDirectoryScreenState extends State<CommunityDirectoryScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    context.read<CommunityBloc>().add(const CommunityFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(trId('local_services')),
      ),
      body: BlocBuilder<CommunityBloc, CommunityState>(
        builder: (context, state) {
          if (state is CommunityLoading || state is CommunityInitial) {
            return const DSSkeletonList();
          }
          if (state is CommunityLoaded) {
            if (state.profiles.isEmpty) {
              return _Empty(lang: lang);
            }
            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<CommunityBloc>()
                    .add(const CommunityFetchRequested());
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: state.profiles
                    .asMap()
                    .entries
                    .map((entry) => FadeSlideIn(
                          delay: Duration(milliseconds: (entry.key * 45).clamp(0, 400)),
                          child: _ProfileCard(profile: entry.value, lang: lang),
                        ))
                    .toList(),
              ),
            );
          }
          if (state is CommunityFailure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<CommunityBloc>()
                        .add(const CommunityFetchRequested()),
                    child: Text(trId('retry')),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final CommunityProfileEntity profile;
  final String lang;

  const _ProfileCard({required this.profile, required this.lang});

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: profile.contactPhone);
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trId('could_not_start_call')),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final desc = profile.displayDescription(lang);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    profile.displayName(lang),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (profile.isVerified)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.verified,
                        size: 18, color: AppColors.primaryLight),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(text: profile.category, color: AppColors.primary),
                if (!profile.isAvailable)
                  _Tag(
                    text: trId('unavailable'),
                    color: AppColors.textSecondary,
                  ),
                if (profile.yearsExperience != null)
                  _Tag(
                    text: tr(
                        en: '${profile.yearsExperience} yrs exp',
                        ta: '${profile.yearsExperience} ஆண்டு அனுபவம்',
                        hi: '${profile.yearsExperience} वर्ष अनुभव',
                        ml: '${profile.yearsExperience} വർഷ പരിചയം'),
                    color: AppColors.accent,
                  ),
              ],
            ),
            if (desc != null && desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                desc,
                style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (profile.serviceArea != null &&
                profile.serviceArea!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      profile.serviceArea!,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            if (profile.hasPhone) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _call(context),
                  icon: const Icon(Icons.call, size: 16),
                  label: Text(trId('call')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String lang;
  const _Empty({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              trId('no_local_services_listed_yet'),
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              trId('this_is_a_directory_of_tradespeople_and'),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
