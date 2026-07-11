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
        title: Text(tr(en: 'Community', ta: 'சமூக அடைவு', hi: 'समुदाय', ml: 'കമ്മ്യൂണിറ്റി')),
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<CommunityBloc>()
                        .add(const CommunityFetchRequested()),
                    child: Text(tr(
                        en: 'Retry',
                        ta: 'மீண்டும் முயற்சிக்கவும்',
                        hi: 'पुनः प्रयास करें',
                        ml: 'വീണ്ടും ശ്രമിക്കുക')),
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
          content: Text(tr(
              en: 'Could not start call',
              ta: 'அழைப்பைத் தொடங்க முடியவில்லை',
              hi: 'कॉल शुरू नहीं हो सका',
              ml: 'കോൾ ആരംഭിക്കാനായില്ല')),
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
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
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
                    text: tr(
                        en: 'Unavailable',
                        ta: 'கிடைக்கவில்லை',
                        hi: 'अनुपलब्ध',
                        ml: 'ലഭ്യമല്ല'),
                    color: Colors.grey,
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
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (profile.serviceArea != null &&
                profile.serviceArea!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      profile.serviceArea!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                  label: Text(tr(en: 'Call', ta: 'அழைக்க', hi: 'कॉल करें', ml: 'വിളിക്കുക')),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👥', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            tr(
                en: 'No profiles yet',
                ta: 'சுயவிவரங்கள் இல்லை',
                hi: 'अभी तक कोई प्रोफ़ाइल नहीं',
                ml: 'ഇതുവരെ പ്രൊഫൈലുകൾ ഇല്ല'),
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
