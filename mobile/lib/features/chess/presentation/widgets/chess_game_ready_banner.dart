import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/router/app_router.dart';
import '../active_game_watcher.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';

/// A persistent top banner shown app-wide whenever the signed-in player has a
/// chess game waiting for them to join. Tapping it opens the game (the online
/// game bloc reads the auth token from storage, so no token needs to be passed
/// here). Hidden while already on the game/spectate screen.
class ChessGameReadyBanner extends StatefulWidget {
  const ChessGameReadyBanner({super.key});

  @override
  State<ChessGameReadyBanner> createState() => _ChessGameReadyBannerState();
}

class _ChessGameReadyBannerState extends State<ChessGameReadyBanner> {
  /// Mirrors the router's current location, updated one frame late.
  ///
  /// The banner has to re-run its route guard when navigation happens, or it
  /// goes stale — painted over the game screen, or failing to come back after
  /// you leave it. The obvious way is to merge `appRouter.routerDelegate`
  /// straight into the AnimatedBuilder, since it is a Listenable.
  ///
  /// That is what this used to do, and it was wrong: go_router notifies its
  /// listeners from inside `Router.setInitialRoutePath`, i.e. while the very
  /// first frame is still building. This widget lives in `MaterialApp.builder`,
  /// above the Navigator, so it cannot use `GoRouterState.of(context)` and the
  /// normal inherited-widget dependency is unavailable. Listening to the
  /// delegate directly therefore marked this widget dirty mid-build, which the
  /// framework reports as "setState() called during build" — and which had been
  /// failing the app-boot test.
  ///
  /// Mirroring the location into a notifier that is written after the frame
  /// keeps the guard live without fighting the build phase.
  final ValueNotifier<String> _location = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    appRouter.routerDelegate.addListener(_syncLocation);
    _syncLocation();
  }

  void _syncLocation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _location.value =
          appRouter.routerDelegate.currentConfiguration.uri.toString();
    });
  }

  @override
  void dispose() {
    appRouter.routerDelegate.removeListener(_syncLocation);
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ChessActiveGameWatcher.instance.game,
        _location,
      ]),
      builder: (context, _) {
        final g = ChessActiveGameWatcher.instance.game.value;
        if (g == null) return const SizedBox.shrink();
        final loc = _location.value;
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
