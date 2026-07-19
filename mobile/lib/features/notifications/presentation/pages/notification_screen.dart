import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/design_system/components/ds_skeleton.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/entrance.dart';
import '../bloc/notification_bloc.dart';
import '../../domain/entities/notification_entity.dart';
import '../../../../service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

/// Local relative-time formatter (avoids a third-party dependency).
String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return tr(en: 'just now', ta: 'இப்போது');
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

/// Which day-bucket a notification falls in, for the grouped inbox.
String _bucketOf(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'today';
  if (diff == 1) return 'yesterday';
  return 'earlier';
}

String _bucketLabel(String bucket) {
  switch (bucket) {
    case 'today':
      return tr(en: 'Today', ta: 'இன்று', hi: 'आज', ml: 'ഇന്ന്');
    case 'yesterday':
      return tr(en: 'Yesterday', ta: 'நேற்று', hi: 'कल', ml: 'ഇന്നലെ');
    default:
      return tr(en: 'Earlier', ta: 'முன்பு', hi: 'पहले', ml: 'നേരത്തെ');
  }
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Ids swiped away this session — filtered from view without a delete endpoint.
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(FetchNotifications());
  }

  /// Fire a self-test push and surface the server's diagnostic (whether Firebase
  /// is configured, whether this device has a token, whether the push went out).
  Future<void> _sendTest(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<NotificationBloc>();
    try {
      final res = await sl<ApiClient>().dio.post('/api/v1/notifications/test');
      final data = res.data;
      final detail = (data is Map && data['detail'] is String)
          ? data['detail'] as String
          : tr(en: 'Test notification sent', ta: 'சோதனை அறிவிப்பு அனுப்பப்பட்டது');
      messenger.showSnackBar(SnackBar(content: Text(detail), duration: const Duration(seconds: 5)));
      bloc.add(FetchNotifications());
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(tr(en: 'Could not send test notification', ta: 'சோதனை அறிவிப்பை அனுப்ப முடியவில்லை')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cSurface,
        elevation: 0,
        title: Text(
          tr(en: 'Notifications', ta: 'அறிவிப்புகள்', hi: 'सूचनाएं', ml: 'അറിയിപ്പുകൾ'),
          style: TextStyle(color: context.cText, fontWeight: FontWeight.w700),
        ),
        iconTheme: IconThemeData(color: context.cText),
        actions: [
          // Admin-only self-test of the push pipeline — pushes to your own
          // device and reports why if it can't.
          BlocBuilder<AuthBloc, AuthState>(builder: (context, auth) {
            final isAdmin = auth is AuthAuthenticated && auth.user.isAdmin;
            if (!isAdmin) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: tr(en: 'Send test notification', ta: 'சோதனை அறிவிப்பு அனுப்பு',
                  hi: 'परीक्षण सूचना भेजें', ml: 'ടെസ്റ്റ് അറിയിപ്പ് അയയ്ക്കുക'),
              onPressed: () => _sendTest(context),
            );
          }),
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () => context.read<NotificationBloc>().add(MarkAllNotificationsAsRead()),
            tooltip: tr(en: 'Mark all as read', ta: 'அனைத்தையும் படித்ததாகக் குறி'),
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const DSSkeletonList();
          } else if (state is NotificationError) {
            return Center(
              child: Text(state.message, style: TextStyle(color: context.cTextSecondary)),
            );
          } else if (state is NotificationLoaded) {
            final items = state.notifications.where((n) => !_dismissed.contains(n.id)).toList();
            if (items.isEmpty) {
              return _EmptyInbox();
            }
            return _buildGroupedList(context, items);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context, List<NotificationEntity> items) {
    // items arrive newest-first from the backend; emit a section header each
    // time the day-bucket changes.
    final children = <Widget>[];
    String? current;
    var tileIndex = 0;
    for (final n in items) {
      final bucket = _bucketOf(n.createdAt);
      if (bucket != current) {
        current = bucket;
        children.add(_SectionHeader(label: _bucketLabel(bucket)));
      }
      children.add(FadeSlideIn(
        delay: Duration(milliseconds: (tileIndex++ * 40).clamp(0, 400)),
        child: _NotificationTile(
          notif: n,
          onDismiss: () {
            setState(() => _dismissed.add(n.id));
            if (!n.isRead) {
              context.read<NotificationBloc>().add(MarkNotificationAsRead(n.id));
            }
          },
          onTap: () {
            context.read<NotificationBloc>().add(TrackNotificationClick(n.id));
            if (!n.isRead) {
              context.read<NotificationBloc>().add(MarkNotificationAsRead(n.id));
            }
            final route = n.data?['route'];
            if (route is String && route.isNotEmpty) context.go(route);
          },
        ),
      ));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: children);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: context.cTextSecondary,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationEntity notif;
  final VoidCallback onDismiss;
  final VoidCallback onTap;
  const _NotificationTile({required this.notif, required this.onDismiss, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        color: AppColors.primary.withOpacity(0.15),
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.check_rounded, color: AppColors.primary),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: notif.isRead
              ? context.cTextSecondary.withOpacity(0.12)
              : AppColors.primary.withOpacity(0.14),
          child: Icon(
            Icons.notifications_rounded,
            color: notif.isRead ? context.cTextSecondary : AppColors.primary,
          ),
        ),
        title: Text(
          notif.titleEn,
          style: TextStyle(
            color: context.cText,
            fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            notif.bodyEn,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.cTextSecondary),
          ),
        ),
        trailing: Text(
          _timeAgo(notif.createdAt),
          style: TextStyle(fontSize: 12, color: context.cTextSecondary),
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: context.cTextSecondary.withOpacity(0.25)),
          const SizedBox(height: 16),
          Text(
            tr(en: 'No notifications right now.', ta: 'இப்போது அறிவிப்புகள் எதுவும் இல்லை.', hi: 'अभी कोई सूचना नहीं।', ml: 'ഇപ്പോൾ അറിയിപ്പുകളൊന്നുമില്ല.'),
            style: TextStyle(color: context.cTextSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
