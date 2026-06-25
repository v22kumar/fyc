import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/issue_entity.dart';
import '../bloc/issue_list_bloc.dart';
import '../bloc/issue_list_event.dart';
import '../bloc/issue_list_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../../../core/widgets/shimmer_loader.dart';
import '../../../../core/widgets/empty_state.dart';
import 'issue_detail_screen.dart';
import 'submit_issue_screen.dart';

class IssuesTrackScreen extends StatefulWidget {
  const IssuesTrackScreen({super.key});

  @override
  State<IssuesTrackScreen> createState() => _IssuesTrackScreenState();
}

class _IssuesTrackScreenState extends State<IssuesTrackScreen> {
  String get _lang => sl<LocalStorage>().getLang();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    context.read<IssueListBloc>().add(const IssueListFetchRequested());
  }

  void _onSelectStatus(String? status) {
    setState(() => _selectedStatus = status);
    context.read<IssueListBloc>().add(IssueListFetchRequested(status: status));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lang == 'ta' ? 'புகார்களைக் கண்காணி' : 'Track Issues'),
      ),
      body: Column(
        children: [
          _StatusFilterBar(
            lang: _lang,
            selected: _selectedStatus,
            onSelect: _onSelectStatus,
          ),
          Expanded(
            child: BlocBuilder<IssueListBloc, IssueListState>(
              builder: (context, state) {
                if (state is IssueListLoading || state is IssueListInitial) {
                  return const ShimmerCardList();
                }
                if (state is IssueListLoaded) {
                  if (state.issues.isEmpty) {
                    return EmptyState(
                      emoji: '📋',
                      title: _lang == 'ta' ? 'புகார்கள் இல்லை' : 'All Clear!',
                      message: _lang == 'ta' ? 'உங்கள் பகுதியில் புகார்கள் எதுவும் இல்லை.' : 'There are no reported issues in your area. Everything looks good!',
                      buttonText: _lang == 'ta' ? 'புதிய புகார்' : 'Report an Issue',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SubmitIssueScreen()),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      context
                          .read<IssueListBloc>()
                          .add(IssueListFetchRequested(status: _selectedStatus));
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: state.issues
                          .map((i) => _IssueCard(issue: i, lang: _lang))
                          .toList(),
                    ),
                  );
                }
                if (state is IssueListFailure) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(state.message),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context
                              .read<IssueListBloc>()
                              .add(IssueListFetchRequested(
                                  status: _selectedStatus)),
                          child: Text(
                              _lang == 'ta' ? 'மீண்டும் முயற்சிக்கவும்' : 'Retry'),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final String lang;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _StatusFilterBar({
    required this.lang,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _Chip(
              label: lang == 'ta' ? 'அனைத்தும்' : 'All',
              color: AppColors.primary,
              selected: selected == null,
              onTap: () => onSelect(null),
            ),
            ...kIssueStatuses.map(
              (s) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _Chip(
                  label: issueStatusLabel(s, lang),
                  color: issueStatusColor(s),
                  selected: selected == s,
                  onTap: () => onSelect(s),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final IssueEntity issue;
  final String lang;

  const _IssueCard({required this.issue, required this.lang});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IssueDetailScreen(issue: issue),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(issue.categoryEmoji,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.categoryLabel(lang),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        issue.displayDescription(lang),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(issue: issue, lang: lang),
              ],
            ),
            if (issue.photoUrl != null && issue.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                child: Image.network(
                  issue.photoUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: AppColors.background,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  fmt.format(issue.createdAt.toLocal()),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IssueEntity issue;
  final String lang;

  const _StatusBadge({required this.issue, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: issue.statusColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        issue.statusLabel(lang),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Removed _EmptyIssues
