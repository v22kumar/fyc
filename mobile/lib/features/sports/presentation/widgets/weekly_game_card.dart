import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/weekly_game_entity.dart';
import '../bloc/sports_bloc.dart';
import '../bloc/sports_event.dart';

class WeeklyGameCard extends StatelessWidget {
  final WeeklyGameEntity game;
  final String lang;
  final String currentUserId;

  const WeeklyGameCard({
    super.key,
    required this.game,
    required this.lang,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOrganizer = game.createdById == currentUserId;
    final bool hasJoined = game.players.any((p) => p.userId == currentUserId);
    final bool isUpcoming = game.status == 'UPCOMING';
    final bool isLive = game.status == 'LIVE';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.cTextPrimary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: context.cBorder.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.02),
                  ],
                ),
                border: Border(
                  bottom: BorderString(color: context.cBorder.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.cSurface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Text('🔥', style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.sports_cricket, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              game.sport.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.cTextSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: game.status),
                ],
              ),
            ),
            
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 18, color: context.cTextSecondary),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEE, MMM d • h:mm a').format(game.scheduledAt),
                        style: TextStyle(
                          color: context.cTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (game.venue != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 18, color: context.cTextSecondary),
                        const SizedBox(width: 8),
                        Text(
                          game.venue!,
                          style: TextStyle(color: context.cTextSecondary),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Players
                  Row(
                    children: [
                      const Icon(Icons.group_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${game.players.length} Players RSVP\'d',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (game.players.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: game.players.map((p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.cSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.cBorder),
                        ),
                        child: Text(
                          p.userName,
                          style: TextStyle(fontSize: 12, color: context.cTextPrimary),
                        ),
                      )).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Actions
                  if (isUpcoming)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: hasJoined
                                ? null
                                : () {
                                    context.read<SportsBloc>().add(SportsWeeklyGameJoinRequested(game.id));
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasJoined ? context.cSurface : AppColors.primary,
                              foregroundColor: hasJoined ? context.cTextSecondary : Colors.white,
                              elevation: hasJoined ? 0 : 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: hasJoined ? BorderSide(color: context.cBorder) : BorderSide.none,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              hasJoined ? 'You\'re In! ✅' : 'Join Game',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        ),
                        if (isOrganizer) ...[
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: game.players.length >= 2
                                ? () {
                                    context.read<SportsBloc>().add(SportsWeeklyGameStartRequested(game.id));
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                            ),
                            child: const Text('Start Game', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    
                  if (isLive && game.fixtureId != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/sports/fixture/${game.fixtureId}/live');
                        },
                        icon: const Icon(Icons.analytics, color: Colors.white),
                        label: const Text('View Live Score', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    
    if (status == 'LIVE') {
      bg = Colors.red.withOpacity(0.15);
      fg = Colors.red.shade700;
      label = 'LIVE';
    } else if (status == 'COMPLETED') {
      bg = Colors.green.withOpacity(0.15);
      fg = Colors.green.shade700;
      label = 'COMPLETED';
    } else {
      bg = AppColors.primary.withOpacity(0.15);
      fg = AppColors.primary;
      label = 'UPCOMING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
