import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/announcement_entity.dart';
import '../bloc/announcement_bloc.dart';
import '../bloc/announcement_event.dart';
import '../bloc/announcement_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../../../core/widgets/shimmer_loader.dart';
import '../../../../core/widgets/scale_on_tap.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

Color announcementCategoryColor(String category) {
  switch (category) {
    case 'BLOOD_REQUEST':
      return Colors.red;
    case 'EVENT':
      return Colors.purple;
    case 'OPPORTUNITY':
      return Colors.blue;
    case 'ALERT':
      return Colors.orange;
    case 'GREEN_DRIVE':
      return Colors.green;
    case 'GENERAL':
    default:
      return Colors.grey;
  }
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    context.read<AnnouncementBloc>().add(const AnnouncementFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'Announcements', ta: 'அறிவிப்புகள்', hi: 'घोषणाएँ', ml: 'അറിയിപ്പുകൾ')),
      ),
      body: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          if (state is AnnouncementLoading) {
            return const ShimmerCardList();
          }
          if (state is AnnouncementLoaded) {
            if (state.announcements.isEmpty) {
              return EmptyState(
                icon: Icons.campaign_rounded,
                title: tr(en: 'No Announcements', ta: 'அறிவிப்புகள் இல்லை', hi: 'कोई घोषणा नहीं', ml: 'അറിയിപ്പുകളൊന്നുമില്ല'),
                message: tr(en: 'You\'re all caught up! There are no new announcements from FYC.', ta: 'FYC இலிருந்து புதிய அறிவிப்புகள் எதுவும் இல்லை.', hi: 'आप पूरी तरह अपडेट हैं! FYC से कोई नई घोषणा नहीं है।', ml: 'നിങ്ങൾ എല്ലാം കണ്ടുകഴിഞ്ഞു! FYC-യിൽ നിന്ന് പുതിയ അറിയിപ്പുകളൊന്നുമില്ല.'),
                buttonText: tr(en: 'Refresh', ta: 'புதுப்பிக்கவும்', hi: 'रिफ्रेश करें', ml: 'പുതുക്കുക'),
                onAction: () => context.read<AnnouncementBloc>().add(const AnnouncementFetchRequested()),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<AnnouncementBloc>()
                    .add(const AnnouncementFetchRequested());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.announcements.length,
                itemBuilder: (context, index) {
                  final announcement = state.announcements[index];
                  return _AnnouncementCard(
                    announcement: announcement,
                    lang: _lang,
                    onTap: () => context.go(
                      '/announcements/detail',
                      extra: announcement,
                    ),
                  );
                },
              ),
            );
          }
          if (state is AnnouncementFailure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: context.cTextSecondary),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<AnnouncementBloc>()
                        .add(const AnnouncementFetchRequested()),
                    child:
                        Text(tr(en: 'Retry', ta: 'மீண்டும் முயற்சிக்கவும்', hi: 'पुनः प्रयास करें', ml: 'വീണ്ടും ശ്രമിക്കുക')),
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

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementEntity announcement;
  final String lang;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.announcement,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final color = announcementCategoryColor(announcement.category);

    return ScaleOnTap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: context.isDark ? null : AppTheme.cardShadow,
          border: Border.all(color: context.cBorder, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${announcement.categoryEmoji} ${announcement.categoryLabel(lang)}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (announcement.isPinned)
                    const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.warning),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                announcement.displayTitle(lang),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.cText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                announcement.displayBody(lang),
                style: TextStyle(color: context.cTextSecondary, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: context.cTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    fmt.format(announcement.createdAt.toLocal()),
                    style: TextStyle(fontSize: 12, color: context.cTextSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Removed _EmptyAnnouncements
