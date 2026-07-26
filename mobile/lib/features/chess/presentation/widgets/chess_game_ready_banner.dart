import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/router/app_router.dart';
import '../active_game_watcher.dart';

/// A persistent top banner shown app-wide whenever the signed-in player has a
/// chess game waiting for them to join. Tapping it opens the game (the online
/// game bloc reads the auth token from storage, so no token needs to be passed
/// here). Hidden while already on the game/spectate screen.
class ChessGameReadyBanner extends StatelessWidget {
  const ChessGameReadyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveChessGame?>(
      valueListenable: ChessActiveGameWatcher.instance.game,
      builder: (context, g, _) {
        if (g == null) return const SizedBox.shrink();
        final loc = appRouter.routerDelegate.currentConfiguration.uri.toString();
        if (loc.contains('/chess/online/') || loc.contains('/chess/spectate/')) {
          return const SizedBox.shrink();
        }
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => appRouter.go('/chess/online/${g.id}', extra: {'color': g.myColor}),
            child: Container(
              width: double.infinity,
              color: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const Text('♟', style: TextStyle(color: Colors.white, fontSize: 15)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trId('your_chess_game_is_ready_tap_to_join'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
