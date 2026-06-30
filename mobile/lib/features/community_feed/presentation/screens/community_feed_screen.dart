import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/community_feed_bloc.dart';
import '../../domain/entities/feed_item_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../../../core/widgets/shimmer_loader.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    context.read<CommunityFeedBloc>().add(const CommunityFeedFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(tr(en: 'Community Feed', ta: 'சமூகப் பதிவு', hi: 'समुदाय फ़ीड', ml: 'കമ്മ്യൂണിറ്റി ഫീഡ്')),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: BlocBuilder<CommunityFeedBloc, CommunityFeedState>(
        builder: (context, state) {
          if (state is CommunityFeedLoading || state is CommunityFeedInitial) {
            return const ShimmerCardList();
          } else if (state is CommunityFeedLoaded) {
            if (state.feed.isEmpty) {
              return EmptyState(
                emoji: '🗞️',
                title: tr(en: 'You\'re All Caught Up!', ta: 'பதிவுகள் இல்லை', hi: 'आप पूरी तरह अपडेट हैं!', ml: 'നിങ്ങൾ എല്ലാം കണ്ടുകഴിഞ്ഞു!'),
                message: tr(en: 'There are no new community updates at the moment.', ta: 'புதிய பதிவுகள் எதுவும் இல்லை.', hi: 'इस समय कोई नया समुदाय अपडेट नहीं है.', ml: 'ഇപ്പോൾ പുതിയ കമ്മ്യൂണിറ്റി അപ്ഡേറ്റുകളൊന്നുമില്ല.'),
                buttonText: tr(en: 'Refresh Feed', ta: 'புதுப்பிக்கவும்', hi: 'फ़ीड रीफ़्रेश करें', ml: 'ഫീഡ് പുതുക്കുക'),
                onAction: () => context.read<CommunityFeedBloc>().add(const CommunityFeedFetchRequested()),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<CommunityFeedBloc>().add(const CommunityFeedFetchRequested());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.feed.length,
                itemBuilder: (context, index) {
                  return _FeedCard(item: state.feed[index], lang: _lang);
                },
              ),
            );
          } else if (state is CommunityFeedFailure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<CommunityFeedBloc>().add(const CommunityFeedFetchRequested());
                    },
                    child: Text(tr(en: 'Retry', ta: 'மீண்டும் முயற்சிக்கவும்', hi: 'पुनः प्रयास करें', ml: 'വീണ്ടും ശ്രമിക്കുക')),
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

class _FeedCard extends StatelessWidget {
  final CommunityFeedItemEntity item;
  final String lang;

  const _FeedCard({required this.item, required this.lang});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    final dateObj = DateTime.tryParse(item.createdAt)?.toLocal() ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            Image.network(
              item.imageUrl!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: double.infinity,
                height: 150,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == 'ta' ? item.displayTitleTa : item.displayTitleEn,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang == 'ta' ? item.displaySubtitleTa : item.displaySubtitleEn,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      fmt.format(dateObj),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    IconData icon;
    Color color;
    String label;

    switch (item.itemType) {
      case 'NEWS':
        icon = Icons.article;
        color = Colors.blue;
        label = tr(en: 'News', ta: 'செய்திகள்', hi: 'समाचार', ml: 'വാർത്തകൾ');
        break;
      case 'EVENT':
        icon = Icons.event;
        color = Colors.purple;
        label = tr(en: 'Event', ta: 'நிகழ்வு', hi: 'कार्यक्रम', ml: 'ഇവന്റ്');
        break;
      case 'TOURNAMENT':
        icon = Icons.emoji_events;
        color = Colors.amber.shade700;
        label = tr(en: 'Tournament', ta: 'விளையாட்டு', hi: 'टूर्नामेंट', ml: 'ടൂർണമെന്റ്');
        break;
      case 'ISSUE':
        icon = Icons.report_problem;
        color = Colors.red;
        label = tr(en: 'Issue', ta: 'புகார்', hi: 'समस्या', ml: 'പ്രശ്നം');
        break;
      case 'ANNOUNCEMENT':
      default:
        icon = Icons.campaign;
        color = Colors.teal;
        label = tr(en: 'Announcement', ta: 'அறிவிப்பு', hi: 'घोषणा', ml: 'അറിയിപ്പ്');
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
