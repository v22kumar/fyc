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
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/success_snackbar.dart';

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
            SuccessSnackbar.show(
              context,
              title: _lang == 'ta' ? 'வெற்றி' : 'Success',
              message: state.message,
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
              return EmptyState(
                emoji: '🎗️',
                title: _lang == 'ta' ? 'தற்போது நிகழ்வுகள் இல்லை' : 'No Events Right Now',
                message: _lang == 'ta' ? 'சமூக நிகழ்வுகளுக்குப் பிறகு மீண்டும் பார்க்கவும்.' : 'Check back later for upcoming community events and initiatives.',
                buttonText: _lang == 'ta' ? 'புதுப்பிக்கவும்' : 'Refresh',
                onAction: () => context.read<EventBloc>().add(const EventFetchRequested()),
              );
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
                  Icon(Icons.error_outline, size: 48, color: context.cTextSecondary),
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: context.cTextSecondary,
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
        color: context.cSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: context.isDark ? null : AppTheme.cardShadow,
        border: Border(
          left: BorderSide(
            color: event.isOngoing
                ? AppColors.success
                : (event.isUpcoming ? AppColors.primary : context.cTextSecondary),
            width: 6,
          ),
          top: BorderSide(color: context.cBorder, width: 1),
          right: BorderSide(color: context.cBorder, width: 1),
          bottom: BorderSide(color: context.cBorder, width: 1),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.cText,
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
                  fmt.format(event.eventStart.toLocal()),
                  style: TextStyle(fontSize: 12, color: context.cTextSecondary),
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
                style: TextStyle(color: context.cTextSecondary, fontSize: 12),
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

// Removed _EmptyEvents
