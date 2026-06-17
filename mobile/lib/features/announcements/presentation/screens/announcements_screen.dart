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
        title: Text(_lang == 'ta' ? 'அறிவிப்புகள்' : 'Announcements'),
      ),
      body: BlocBuilder<AnnouncementBloc, AnnouncementState>(
        builder: (context, state) {
          if (state is AnnouncementLoading) {
            return const ShimmerCardList();
          }
          if (state is AnnouncementLoaded) {
            if (state.announcements.isEmpty) {
              return _EmptyAnnouncements(lang: _lang);
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<AnnouncementBloc>()
                        .add(const AnnouncementFetchRequested()),
                    child:
                        Text(_lang == 'ta' ? 'மீண்டும் முயற்சிக்கவும்' : 'Retry'),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppColors.border, width: 1),
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
                    const Text('📌', style: TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                announcement.displayTitle(lang),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                announcement.displayBody(lang),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    fmt.format(announcement.createdAt.toLocal()),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

class _EmptyAnnouncements extends StatelessWidget {
  final String lang;
  const _EmptyAnnouncements({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📢', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            lang == 'ta' ? 'அறிவிப்புகள் இல்லை' : 'No announcements yet',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
