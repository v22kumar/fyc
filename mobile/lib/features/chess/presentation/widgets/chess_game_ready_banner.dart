import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/router/app_router.dart';
import '../active_game_watcher.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';

/// A persistent top banner shown app-wide whenever the signed-in player has a
/// chess game waiting for them to join. Tapping it opens the game (the online
/// game bloc reads the auth token from storage, so no token needs to be passed
/// here). Hidden while already on the game/spectate screen.
class ChessGameReadyBanner extends StatelessWidget {
  const ChessGameReadyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild on BOTH a change to the joinable game AND on navigation. The
    // route check below is only correct if this widget re-runs when the route
    // changes — a const widget keyed on `game` alone would evaluate the guard
    // once and go stale, leaving the banner painted over the game screen (or
    // failing to reappear after you leave it). go_router's routerDelegate is a
    // Listenable, so merging it in makes the guard track the live route.
    return AnimatedBuilder(
      animation: Listenable.merge([
        ChessActiveGameWatcher.instance.game,
        appRouter.routerDelegate,
      ]),
      builder: (context, _) {
        final g = ChessActiveGameWatcher.instance.game.value;
        if (g == null) return const SizedBox.shrink();
        final loc = appRouter.routerDelegate.currentConfiguration.uri.toString();
        if (loc.contains('/chess/online/') || loc.contains('/chess/spectate/')) {
          return const SizedBox.shrink();
        }
        return Material(
          color: const Color(0xFF16A34A),
          child: InkWell(
            onTap: () => appRouter.go('/chess/online/${g.id}', extra: {'color': g.myColor}),
            // Keep the green background bleeding into the status-bar area, but
            // pad the content below the notch/clock so the text is never hidden.
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    Text('♟', style: TextStyle(color: AppColors.background, fontSize: 15)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trId('your_chess_game_is_ready_tap_to_join'),
                        style: TextStyle(
                            color: AppColors.background, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: AppColors.background, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
