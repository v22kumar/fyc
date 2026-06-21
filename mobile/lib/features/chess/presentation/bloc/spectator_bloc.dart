import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants/api_constants.dart';
import 'spectator_event.dart';
import 'spectator_state.dart';

/// A minimal WebSocket client that connects to the /spectate endpoint.
/// Reconnects automatically with exponential backoff, mirroring ChessWsClient.
class _SpectatorWsClient {
  final String gameId;
  final String token;

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  bool _disposed = false;
  int _reconnectDelay = 1;

  _SpectatorWsClient({required this.gameId, required this.token});

  Stream<Map<String, dynamic>> get messages {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  void connect() {
    if (_disposed) return;
    final uri = Uri.parse(
      '${ApiConstants.chessGameSpectateWs(gameId)}?token=$token',
    );
    _channel = IOWebSocketChannel.connect(uri);
    _channel!.stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  void send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (_) {}
  }

  void _onData(dynamic raw) {
    _reconnectDelay = 1;
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      _controller?.add(msg);
    } catch (_) {}
  }

  void _onError(Object error) {
    _controller?.add({'type': 'connection_error', 'message': error.toString()});
  }

  void _onDone() {
    if (_disposed) return;
    _controller?.add({'type': 'disconnected'});
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    Future.delayed(Duration(seconds: _reconnectDelay), () {
      if (_disposed) return;
      _reconnectDelay = (_reconnectDelay * 2).clamp(1, 30);
      connect();
    });
  }

  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    _controller?.close();
    _channel = null;
    _controller = null;
  }
}

class SpectatorBloc extends Bloc<SpectatorEvent, SpectatorState> {
  _SpectatorWsClient? _wsClient;
  StreamSubscription? _wsSub;

  SpectatorBloc() : super(const SpectatorConnecting()) {
    on<ConnectSpectator>(_onConnect);
    on<DisconnectSpectator>(_onDisconnect);
    on<_SpectatorMessage>(_onServerMsg);
  }

  @override
  Future<void> close() {
    _wsSub?.cancel();
    _wsClient?.dispose();
    return super.close();
  }

  // ── Connect ────────────────────────────────────────────────────────────────

  void _onConnect(ConnectSpectator event, Emitter<SpectatorState> emit) {
    emit(const SpectatorConnecting());

    _wsClient = _SpectatorWsClient(
      gameId: event.gameId,
      token: event.token,
    );
    _wsSub = _wsClient!.messages.listen(
      (msg) => add(_SpectatorMessage(msg)),
    );
    _wsClient!.connect();
  }

  void _onDisconnect(DisconnectSpectator event, Emitter<SpectatorState> emit) {
    _wsSub?.cancel();
    _wsClient?.dispose();
    _wsClient = null;
    _wsSub = null;
    emit(const SpectatorConnecting());
  }

  // ── Server messages ────────────────────────────────────────────────────────

  void _onServerMsg(_SpectatorMessage event, Emitter<SpectatorState> emit) {
    final msg = event.msg;
    final type = msg['type'] as String?;

    switch (type) {
      case 'state':
        _handleStateSnapshot(msg, emit);

      case 'game_start':
        _handleStateSnapshot(msg, emit);

      case 'move':
        _handleMove(msg, emit);

      case 'game_over':
        final s = state;
        final wn = s is SpectatorWatching ? s.whiteName : 'White';
        final bn = s is SpectatorWatching ? s.blackName : 'Black';
        final sans = s is SpectatorWatching ? s.moveSans : <String>[];
        emit(SpectatorGameOver(
          result: msg['result'] as String? ?? 'draw',
          reason: msg['reason'] as String? ?? 'unknown',
          whiteName: wn,
          blackName: bn,
          moveSans: sans,
        ));

      case 'spectator_count':
        final s = state;
        if (s is SpectatorWatching) {
          final count = msg['count'] as int? ?? s.spectatorCount;
          emit(s.copyWith(spectatorCount: count));
        }
    }
  }

  void _handleStateSnapshot(
      Map<String, dynamic> msg, Emitter<SpectatorState> emit) {
    final whiteName = msg['white_name'] as String? ?? 'White';
    final blackName = msg['black_name'] as String? ?? 'Black';
    final rawMoves = msg['moves'] as List?;
    final moveSans =
        rawMoves?.map((m) => m['san'] as String? ?? '').toList() ?? <String>[];
    final currentTurn = msg['turn'] as String? ?? 'white';
    final tc = msg['time_control'] as String? ?? 'untimed';

    final clockRaw = msg['clock'] as Map<String, dynamic>?;
    final int? whiteMs =
        clockRaw != null ? (clockRaw['white'] as num?)?.toInt() : null;
    final int? blackMs =
        clockRaw != null ? (clockRaw['black'] as num?)?.toInt() : null;

    // Rebuild bishop.Game from move list
    final engine = bishop.Game(variant: bishop.Variant.standard());
    if (rawMoves != null) {
      for (final m in rawMoves) {
        final uci = m['uci'] as String?;
        if (uci != null) _applyUci(engine, uci);
      }
    }

    // Spectators always view from white's perspective
    final boardState = engine.squaresState(Squares.white);

    final s = state;
    final existingSpectatorCount =
        s is SpectatorWatching ? s.spectatorCount : 0;

    emit(SpectatorWatching(
      engine: engine,
      boardState: boardState,
      whiteName: whiteName,
      blackName: blackName,
      moveSans: List<String>.from(moveSans),
      currentTurn: currentTurn,
      timeControl: tc,
      whiteTimeMs: whiteMs,
      blackTimeMs: blackMs,
      spectatorCount: existingSpectatorCount,
    ));
  }

  void _handleMove(
      Map<String, dynamic> msg, Emitter<SpectatorState> emit) {
    final s = state;
    if (s is! SpectatorWatching) return;

    final uci = msg['uci'] as String?;
    final san = msg['san'] as String? ?? '';
    final currentTurn = msg['turn'] as String? ?? 'white';

    final clockRaw = msg['clock'] as Map<String, dynamic>?;
    final int? newWhiteMs =
        clockRaw != null ? (clockRaw['white'] as num?)?.toInt() : null;
    final int? newBlackMs =
        clockRaw != null ? (clockRaw['black'] as num?)?.toInt() : null;

    if (uci != null) _applyUci(s.engine, uci);

    final newSans = List<String>.from(s.moveSans)..add(san);

    emit(s.copyWith(
      boardState: s.engine.squaresState(Squares.white),
      moveSans: newSans,
      currentTurn: currentTurn,
      whiteTimeMs: newWhiteMs ?? s.whiteTimeMs,
      blackTimeMs: newBlackMs ?? s.blackTimeMs,
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _applyUci(bishop.Game engine, String uci) {
    final moves = engine.generateLegalMoves();
    for (final m in moves) {
      if (m.algebraic() == uci) {
        return engine.makeMove(m);
      }
    }
    return false;
  }
}
