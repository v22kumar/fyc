import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/announcement_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import 'announcements_screen.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  final AnnouncementEntity announcement;
  const AnnouncementDetailScreen({super.key, required this.announcement});

  String get _lang => sl<LocalStorage>().getLang();

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy · h:mm a');
    final color = announcementCategoryColor(announcement.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'Announcement', ta: 'அறிவிப்பு', hi: 'घोषणा', ml: 'അറിയിപ്പ്')),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (announcement.bannerUrl != null &&
              announcement.bannerUrl!.isNotEmpty)
            Image.network(
              announcement.bannerUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200,
                color: AppColors.background,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    size: 48, color: Colors.grey),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingPage),
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
                        '${announcement.categoryEmoji} ${announcement.categoryLabel(_lang)}',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (announcement.isPinned)
                      const Text('📌', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  announcement.displayTitle(_lang),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      fmt.format(announcement.createdAt.toLocal()),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  announcement.displayBody(_lang),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
