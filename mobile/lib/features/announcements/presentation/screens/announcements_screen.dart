import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/announcement_entity.dart';
import '../bloc/announcement_bloc.dart';
import '../bloc/announcement_event.dart';
import '../bloc/announcement_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_loader.dart';
import '../../../../core/widgets/scale_on_tap.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

Color announcementCategoryColor(String category) {
  switch (category) {
    case 'BLOOD_REQUEST':
      return AppColors.danger;
    case 'EVENT':
      return Colors.purple;
    case 'OPPORTUNITY':
      return AppColors.info;
    case 'ALERT':
      return AppColors.warning;
    case 'GREEN_DRIVE':
      return AppColors.success;
    case 'GENERAL':
    default:
      return AppColors.textSecondary;
  }
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  String get _lang => trLang();

  @override
  void initState() {
    super.initState();
    context.read<AnnouncementBloc>().add(const AnnouncementFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(trId('announcements')),
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
                title: trId('no_announcements'),
                message: trId('you_re_all_caught_up_there_are_no_new_an'),
                buttonText: trId('refresh_2'),
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
                        Text(trId('retry')),
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
                      color: color.withValues(alpha: 0.12),
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
                    Icon(Icons.push_pin_rounded, size: 16, color: AppColors.warning),
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
