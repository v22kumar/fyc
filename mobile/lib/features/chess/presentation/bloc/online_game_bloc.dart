import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/chess_ws_client.dart';
import 'online_game_event.dart';
import 'online_game_state.dart';

class OnlineGameBloc extends Bloc<OnlineGameEvent, OnlineGameState> {
  ChessWsClient? _wsClient;
  StreamSubscription? _wsSub;
  String _myColor = 'white';
  Timer? _clockTimer;

  OnlineGameBloc() : super(const OnlineGameConnecting()) {
    on<ConnectToGame>(_onConnect);
    on<SendMove>(_onSendMove);
    on<SendResign>(_onResign);
    on<SendOfferDraw>(_onOfferDraw);
    on<SendAcceptDraw>(_onAcceptDraw);
    on<SendDeclineDraw>(_onDeclineDraw);
    on<FlipOnlineBoard>(_onFlip);
    on<SendFlag>(_onSendFlag);
    on<ClockTick>(_onClockTick);
    on<ServerMessage>(_onServerMsg);
  }

  @override
  Future<void> close() {
    _clockTimer?.cancel();
    _wsSub?.cancel();
    _wsClient?.dispose();
    return super.close();
  }

  // ── Connect ────────────────────────────────────────────────────────────────

  void _onConnect(ConnectToGame event, Emitter<OnlineGameState> emit) {
    _myColor = event.myColor;
    emit(const OnlineGameConnecting());

    _wsClient = ChessWsClient(
      gameId: event.gameId,
      // Read the token fresh from storage each connect; fall back to the token
      // passed at navigation. This makes push/deep-link entry (which carries no
      // token) work, and keeps reconnects using a non-expired token.
      tokenProvider: () async {
        final stored = await sl<LocalStorage>().getToken();
        return (stored != null && stored.isNotEmpty) ? stored : event.token;
      },
    );
    _wsSub = _wsClient!.messages.listen(
      (msg) => add(ServerMessage(msg)),
    );
    _wsClient!.connect();
  }

  // ── Clock ──────────────────────────────────────────────────────────────────

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(const ClockTick());
    });
  }

  void _stopClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  void _onClockTick(ClockTick event, Emitter<OnlineGameState> emit) {
    final s = state;
    if (s is! OnlineGameInProgress || !s.isTimed) return;

    final isWhite = s.myColor == 'white';
    final activeWhite = s.isMyTurn == isWhite;

    int newWhite = s.whiteTimeMs ?? 0;
    int newBlack = s.blackTimeMs ?? 0;

    if (activeWhite) {
      newWhite = (newWhite - 1000).clamp(0, 999999999);
    } else {
      newBlack = (newBlack - 1000).clamp(0, 999999999);
    }

    emit(s.copyWith(whiteTimeMs: newWhite, blackTimeMs: newBlack));

    // Claim the flag when the clock of whoever is ON MOVE hits zero — ours OR
    // the opponent's. Previously only our own flag was reported, so a player
    // waiting on a stalling opponent had no way to end the game. The server
    // re-checks against its own authoritative clock, so a premature or false
    // claim is simply rejected and resynced.
    final activeTime = activeWhite ? newWhite : newBlack;
    if (activeTime == 0) {
      _stopClockTimer();
      add(const SendFlag());
    }
  }

  void _onSendFlag(SendFlag event, Emitter<OnlineGameState> emit) {
    _wsClient?.send({'type': 'flag'});
  }

  // ── Server messages ────────────────────────────────────────────────────────

  void _onServerMsg(ServerMessage event, Emitter<OnlineGameState> emit) {
    final msg = event.msg;
    final type = msg['type'] as String?;

    switch (type) {
      case 'waiting':
        // 'waiting' also carries the authoritative colour — adopt it.
        final wc = msg['color'] as String?;
        if (wc == 'white' || wc == 'black') _myColor = wc!;
        emit(OnlineGameWaiting(myColor: _myColor));

      case 'game_start':
      case 'state':
        _handleStateOrStart(msg, emit);

      case 'move':
        _handleServerMove(msg, emit);

      case 'game_over':
        _stopClockTimer();
        final s = state;
        final wn = s is OnlineGameInProgress ? s.whiteName : 'White';
        final bn = s is OnlineGameInProgress ? s.blackName : 'Black';
        final sans = s is OnlineGameInProgress ? s.moveSans : <String>[];
        emit(OnlineGameOver(
          result: msg['result'] as String? ?? 'draw',
          reason: msg['reason'] as String? ?? 'unknown',
          whiteName: wn,
          blackName: bn,
          moveSans: sans,
        ));

      case 'draw_offered':
        final s = state;
        if (s is OnlineGameInProgress) {
          emit(s.copyWith(drawOffered: true));
        }

      case 'draw_declined':
        final s = state;
        if (s is OnlineGameInProgress) {
          emit(s.copyWith(drawOffered: false));
        }

      case 'opponent_disconnected':
        final s = state;
        if (s is OnlineGameInProgress) {
          emit(s.copyWith(opponentDisconnected: true));
        }

      case 'opponent_reconnected':
        final s = state;
        if (s is OnlineGameInProgress) {
          emit(s.copyWith(opponentDisconnected: false));
        }

      case 'latency_probe':
        // Answer at once. The round trip the server measures from this is what
        // gets refunded to our clock on the next move, so any delay we add here
        // is time we lose ourselves.
        _wsClient?.send({'type': 'latency_pong'});

      case 'game_paused':
        // The server could not durably save a move and froze the board until an
        // organizer intervenes. Web already surfaced this; without it here a
        // Flutter player just saw their moves silently refused.
        _stopClockTimer();
        final s = state;
        if (s is OnlineGameInProgress) {
          emit(s.copyWith(paused: true, moveInFlight: false));
        }

      case 'error':
        final s = state;
        if (s is OnlineGameInProgress) {
          emit(s.copyWith(moveInFlight: false));
          // Restart clock if it was stopped optimistically
          if (s.isTimed) _startClockTimer();
          // Any rejected message means our board may no longer match the
          // server's. Ask for the authoritative position instead of sitting
          // on a stale one waiting for an echo that will never arrive.
          _wsClient?.send({'type': 'sync'});
        }

      case 'disconnected':
      case 'connection_error':
        // Client auto-reconnects; pause the clock to avoid unfair deduction and
        // surface a "Reconnecting…" state so the player knows the board is
        // temporarily frozen (not that the app hung). Any authoritative message
        // that arrives on the fresh socket clears it — the reconnect always
        // replays a full 'state' snapshot, and 'move'/'game_over' clear it too.
        _stopClockTimer();
        final s = state;
        if (s is OnlineGameInProgress) {
          if (!s.reconnecting) emit(s.copyWith(reconnecting: true));
        } else if (s is OnlineGameConnecting) {
          if (!s.reconnecting) emit(const OnlineGameConnecting(reconnecting: true));
        }

      // pong and spectator_count are no-ops for the player client
      case 'pong':
      case 'spectator_count':
        break;
    }
  }

  void _handleStateOrStart(Map<String, dynamic> msg, Emitter<OnlineGameState> emit) {
    // The server is authoritative for OUR colour: the per-user 'state' snapshot
    // carries "color" (the shared 'game_start' broadcast does not). Trust it over
    // the connect-time guess — otherwise a wrong guess flips orientation and turn,
    // and both players end up stuck seeing "your turn" unable to move.
    final serverColor = msg['color'] as String?;
    if (serverColor == 'white' || serverColor == 'black') _myColor = serverColor!;

    final whiteName = msg['white_name'] as String? ?? 'White';
    final blackName = msg['black_name'] as String? ?? 'Black';
    final rawMoves = msg['moves'] as List?;
    final moveSans = rawMoves?.map((m) => m['san'] as String? ?? '').toList() ?? <String>[];
    final serverTurn = msg['turn'] as String? ?? 'white';
    final isMyTurn = serverTurn == _myColor;
    final orientation = _myColor == 'white' ? Squares.white : Squares.black;
    final tc = msg['time_control'] as String? ?? 'untimed';

    final clockRaw = msg['clock'] as Map<String, dynamic>?;
    final int? whiteMs = clockRaw != null ? (clockRaw['white'] as num?)?.toInt() : null;
    final int? blackMs = clockRaw != null ? (clockRaw['black'] as num?)?.toInt() : null;

    // Rebuild bishop.Game from move list
    final engine = bishop.Game(variant: bishop.Variant.standard());
    if (rawMoves != null) {
      for (final m in rawMoves) {
        final uci = m['uci'] as String?;
        if (uci != null) _applyUci(engine, uci);
      }
    }

    emit(OnlineGameInProgress(
      engine: engine,
      boardState: engine.squaresState(orientation),
      orientation: orientation,
      myColor: _myColor,
      whiteName: whiteName,
      blackName: blackName,
      moveSans: List<String>.from(moveSans),
      isMyTurn: isMyTurn,
      timeControl: tc,
      whiteTimeMs: whiteMs,
      blackTimeMs: blackMs,
    ));

    // Run the ticker for the whole game, not just our own turn — otherwise the
    // opponent's clock appears frozen while they think, and their flag can
    // never be noticed. Whose clock actually decrements is decided per tick.
    if (tc != 'untimed' && whiteMs != null) {
      _startClockTimer();
    } else {
      _stopClockTimer();
    }
  }

  void _handleServerMove(Map<String, dynamic> msg, Emitter<OnlineGameState> emit) {
    final s = state;
    if (s is! OnlineGameInProgress) return;

    final uci = msg['uci'] as String?;
    final san = msg['san'] as String? ?? '';
    final serverTurn = msg['turn'] as String? ?? 'white';

    // Update clock from server (authoritative)
    final clockRaw = msg['clock'] as Map<String, dynamic>?;
    final int? newWhiteMs = clockRaw != null ? (clockRaw['white'] as num?)?.toInt() : null;
    final int? newBlackMs = clockRaw != null ? (clockRaw['black'] as num?)?.toInt() : null;

    if (uci != null) _applyUci(s.engine, uci);

    final newSans = List<String>.from(s.moveSans)..add(san);
    final isMyTurn = serverTurn == _myColor;

    emit(s.copyWith(
      boardState: s.engine.squaresState(s.orientation),
      moveSans: newSans,
      isMyTurn: isMyTurn,
      moveInFlight: false,
      reconnecting: false, // a live move means the socket is healthy again
      whiteTimeMs: newWhiteMs ?? s.whiteTimeMs,
      blackTimeMs: newBlackMs ?? s.blackTimeMs,
    ));

    // Keep ticking for both sides — the tick handler decrements whichever clock
    // is running, so the opponent's time visibly counts down too.
    if (s.isTimed) _startClockTimer();
  }

  // ── Outgoing moves ─────────────────────────────────────────────────────────

  void _onSendMove(SendMove event, Emitter<OnlineGameState> emit) {
    final s = state;
    if (s is! OnlineGameInProgress || !s.isMyTurn || s.moveInFlight) return;
    if (s.paused) return;   // frozen by the server — the move would be refused

    _stopClockTimer(); // pause local countdown while waiting for echo
    final uci = _moveToUci(event.move);
    _wsClient?.send({'type': 'move', 'uci': uci});
    emit(s.copyWith(moveInFlight: true, isMyTurn: false));
  }

  void _onResign(SendResign event, Emitter<OnlineGameState> emit) {
    _stopClockTimer();
    _wsClient?.send({'type': 'resign'});
  }

  void _onOfferDraw(SendOfferDraw event, Emitter<OnlineGameState> emit) {
    _wsClient?.send({'type': 'offer_draw'});
  }

  void _onAcceptDraw(SendAcceptDraw event, Emitter<OnlineGameState> emit) {
    _stopClockTimer();
    _wsClient?.send({'type': 'accept_draw'});
  }

  void _onDeclineDraw(SendDeclineDraw event, Emitter<OnlineGameState> emit) {
    final s = state;
    if (s is OnlineGameInProgress) {
      emit(s.copyWith(drawOffered: false));
    }
    _wsClient?.send({'type': 'decline_draw'});
  }

  void _onFlip(FlipOnlineBoard event, Emitter<OnlineGameState> emit) {
    final s = state;
    if (s is! OnlineGameInProgress) return;
    final newOri = s.orientation == Squares.white ? Squares.black : Squares.white;
    emit(s.copyWith(
      orientation: newOri,
      boardState: s.engine.squaresState(newOri),
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _applyUci(bishop.Game engine, String uci) {
    final moves = engine.generateLegalMoves();
    for (final m in moves) {
      if (engine.toAlgebraic(m) == uci) {
        return engine.makeMove(m);
      }
    }
    return false;
  }

  String _moveToUci(Move move) {
    String sq(int s) {
      final file = String.fromCharCode(97 + (s % 8));
      final rank = (s ~/ 8 + 1).toString();
      return '$file$rank';
    }
    final base = '${sq(move.from)}${sq(move.to)}';
    if (move.promo != null && move.promo!.isNotEmpty) {
      return '$base${move.promo!.toLowerCase()}';
    }
    return base;
  }
}
