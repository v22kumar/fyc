import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../service_locator.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';

/// A chess game the signed-in player can join right now.
class ActiveChessGame {
  final String id;
  final String myColor; // 'white' | 'black'
  const ActiveChessGame(this.id, this.myColor);
}

/// Always-on watcher that answers "do I have a chess game to join?" by polling
/// `GET /chess/games/active`, so a player is pulled into an accepted game from
/// ANYWHERE in the app.
///
/// This is the reliability fix for the core "multiplayer doesn't reach the
/// opponent" bug: previously the challenger was only routed into the game by a
/// poll that lived on the Challenge screen (cancelled the moment they navigated
/// away) plus a best-effort push that is off unless Firebase is configured. The
/// watcher decouples "get into the game" from any one screen or from push.
class ChessActiveGameWatcher {
  ChessActiveGameWatcher._();
  static final ChessActiveGameWatcher instance = ChessActiveGameWatcher._();

  /// The current joinable game (or null). A global banner listens to this.
  final ValueNotifier<ActiveChessGame?> game = ValueNotifier<ActiveChessGame?>(null);

  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 7), (_) => _poll());
    _poll();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    game.value = null;
  }

  Future<void> _poll() async {
    final auth = sl<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      game.value = null;
      return;
    }
    try {
      final res = await sl<ApiClient>().dio.get('${ApiConstants.chessGames}/active');
      final data = res.data;
      if (data is! Map || data['id'] == null) {
        game.value = null;
        return;
      }
      final id = data['id'].toString();
      final myColor = (data['white_id']?.toString() == auth.user.id) ? 'white' : 'black';
      final next = ActiveChessGame(id, myColor);
      if (game.value?.id != next.id || game.value?.myColor != next.myColor) {
        game.value = next;
      }
    } catch (_) {
      // Best-effort: keep the last value; a 401 triggers the dio refresh
      // interceptor so the next poll succeeds.
    }
  }
}
