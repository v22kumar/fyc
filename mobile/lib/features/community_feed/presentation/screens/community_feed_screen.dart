import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/community_feed_bloc.dart';
import '../../domain/entities/feed_item_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_loader.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  String get _lang => trLang();

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
        title: Text(trId('community_feed')),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: BlocBuilder<CommunityFeedBloc, CommunityFeedState>(
        builder: (context, state) {
          if (state is CommunityFeedLoading || state is CommunityFeedInitial) {
            return const ShimmerCardList();
          } else if (state is CommunityFeedLoaded) {
            if (state.feed.isEmpty) {
              return EmptyState(
                emoji: '🗞️',
                title: trId('you_re_all_caught_up'),
                message: trId('there_are_no_new_community_updates_at_th'),
                buttonText: trId('refresh_feed'),
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
                  Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<CommunityFeedBloc>().add(const CommunityFeedFetchRequested());
                    },
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
                color: AppColors.textSecondary.withValues(alpha: 0.2),
                child: Icon(Icons.broken_image, color: AppColors.textSecondary),
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
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      fmt.format(dateObj),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
        color = AppColors.info;
        label = trId('news');
        break;
      case 'EVENT':
        icon = Icons.event;
        color = Colors.purple;
        label = trId('event');
        break;
      case 'TOURNAMENT':
        icon = Icons.emoji_events;
        color = AppColors.warning.withValues(alpha: 0.7);
        label = trId('tournament');
        break;
      case 'ISSUE':
        icon = Icons.report_problem;
        color = AppColors.danger;
        label = trId('issue');
        break;
      case 'ANNOUNCEMENT':
      default:
        icon = Icons.campaign;
        color = Colors.teal;
        label = trId('announcement');
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
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
