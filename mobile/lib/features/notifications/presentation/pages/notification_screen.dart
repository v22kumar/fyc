import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/notification_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(FetchNotifications());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () {
              context.read<NotificationBloc>().add(MarkAllNotificationsAsRead());
            },
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is NotificationError) {
            return Center(child: Text(state.message));
          } else if (state is NotificationLoaded) {
            final notifications = state.notifications;
            if (notifications.isEmpty) {
              return const Center(child: Text('No notifications right now.'));
            }
            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: notif.isRead ? Colors.grey[200] : Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.notifications,
                      color: notif.isRead ? Colors.grey : Theme.of(context).primaryColor,
                    ),
                  ),
                  title: Text(
                    notif.titleEn,
                    style: TextStyle(
                      fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notif.bodyEn),
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(notif.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  onTap: () {
                    context.read<NotificationBloc>().add(TrackNotificationClick(notif.id));
                    if (!notif.isRead) {
                      context.read<NotificationBloc>().add(MarkNotificationAsRead(notif.id));
                    }
                    if (notif.data != null && notif.data!['route'] != null) {
                      context.go(notif.data!['route']);
                    }
                  },
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
