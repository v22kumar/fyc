import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants/api_constants.dart';

/// WebSocket client for a single online chess game.
/// Reconnects automatically with exponential backoff.
class ChessWsClient {
  final String gameId;
  final String token;

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  bool _disposed = false;
  int _reconnectDelay = 1; // seconds

  ChessWsClient({required this.gameId, required this.token});

  Stream<Map<String, dynamic>> get messages {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  void connect() {
    if (_disposed) return;
    final uri = Uri.parse('${ApiConstants.chessGameWs(gameId)}?token=$token');
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
    _reconnectDelay = 1; // reset on successful message
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
