import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/event_entity.dart';
import '../bloc/event_bloc.dart';
import '../bloc/event_event.dart';
import '../bloc/event_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

import '../../../../core/widgets/shimmer_loader.dart';
import '../../../../core/widgets/scale_on_tap.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    context.read<EventBloc>().add(const EventFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lang == 'ta' ? 'நிகழ்வுகள்' : 'Events'),
      ),
      body: BlocConsumer<EventBloc, EventState>(
        listener: (context, state) {
          if (state is EventCheckinSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.primary,
              ),
            );
            context.read<EventBloc>().add(const EventFetchRequested());
          }
          if (state is EventFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.accent,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is EventLoading) {
            return const ShimmerCardList();
          }
          if (state is EventLoaded) {
            if (state.events.isEmpty) {
              return _EmptyEvents(lang: _lang);
            }
            final upcoming = state.events.where((e) => e.isUpcoming).toList();
            final past = state.events.where((e) => !e.isUpcoming).toList();
            return RefreshIndicator(
              onRefresh: () async {
                context.read<EventBloc>().add(const EventFetchRequested());
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (upcoming.isNotEmpty) ...[
                    _SectionHeader(
                      label: _lang == 'ta' ? 'வரவிருக்கும் நிகழ்வுகள்' : 'Upcoming Events',
                    ),
                    ...upcoming.map((e) => _EventCard(
                          event: e,
                          lang: _lang,
                          onCheckin: () => context
                              .read<EventBloc>()
                              .add(EventCheckinRequested(e.id)),
                        )),
                  ],
                  if (past.isNotEmpty) ...[
                    _SectionHeader(
                      label: _lang == 'ta' ? 'கடந்த நிகழ்வுகள்' : 'Past Events',
                    ),
                    ...past.map((e) => _EventCard(
                          event: e,
                          lang: _lang,
                          onCheckin: null,
                        )),
                  ],
                ],
              ),
            );
          }
          if (state is EventFailure) {
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
                        .read<EventBloc>()
                        .add(const EventFetchRequested()),
                    child: Text(_lang == 'ta' ? 'மீண்டும் முயற்சிக்கவும்' : 'Retry'),
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

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventEntity event;
  final String lang;
  final VoidCallback? onCheckin;

  const _EventCard({
    required this.event,
    required this.lang,
    required this.onCheckin,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy · h:mm a');
    final isPast = !event.isUpcoming && !event.isOngoing;

    Widget cardContent = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow,
        border: Border(
          left: BorderSide(
            color: event.isOngoing
                ? AppColors.success
                : (event.isUpcoming ? AppColors.primary : AppColors.textSecondary),
            width: 6,
          ),
          top: const BorderSide(color: AppColors.border, width: 1),
          right: const BorderSide(color: AppColors.border, width: 1),
          bottom: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.displayTitle(lang),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (event.isOngoing)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              event.displayDescription(lang),
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
                  fmt.format(event.eventStart.toLocal()),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (onCheckin != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCheckin,
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: Text(lang == 'ta' ? 'செக்-இன் செய்க' : 'Check In'),
                ),
              ),
            ] else if (isPast) ...[
              const SizedBox(height: 8),
              Text(
                lang == 'ta' ? 'நிகழ்வு முடிந்தது' : 'Event ended',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );

    if (onCheckin != null) {
      return ScaleOnTap(
        onTap: onCheckin,
        child: cardContent,
      );
    }
    return cardContent;
  }
}

class _EmptyEvents extends StatelessWidget {
  final String lang;
  const _EmptyEvents({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎗️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            lang == 'ta' ? 'நிகழ்வுகள் இல்லை' : 'No events yet',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
