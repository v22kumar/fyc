import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants/api_constants.dart';

/// WebSocket client for a single online chess game.
/// Reconnects automatically with exponential backoff.
/// Sends application-level pings every 30 s to prevent proxy timeouts (Fly.io
/// drops idle WebSocket connections after ~60 s).
class ChessWsClient {
  final String gameId;
  final String token;

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  Timer? _pingTimer;
  bool _disposed = false;
  int _reconnectDelay = 1; // seconds

  ChessWsClient({required this.gameId, required this.token});

  Stream<Map<String, dynamic>> get messages {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  void connect() {
    if (_disposed) return;
    _cancelPingTimer();
    final uri = Uri.parse('${ApiConstants.chessGameWs(gameId)}?token=$token');
    _channel = IOWebSocketChannel.connect(uri);
    _channel!.stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
    _startPingTimer();
  }

  void send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (_) {}
  }

  void _onData(dynamic raw) {
    _reconnectDelay = 1; // reset on successful message
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      _controller?.add(msg);
    } catch (_) {}
  }

  void _onError(Object error) {
    _cancelPingTimer();
    _controller?.add({'type': 'connection_error', 'message': error.toString()});
  }

  void _onDone() {
    _cancelPingTimer();
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

  void _startPingTimer() {
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send({'type': 'ping'});
    });
  }

  void _cancelPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void dispose() {
    _disposed = true;
    _cancelPingTimer();
    _channel?.sink.close();
    _controller?.close();
    _channel = null;
    _controller = null;
  }
}
