import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../core/constants/api_constants.dart';

/// WebSocket client for a single online chess game.
///
/// Reconnects automatically, forever, with backoff and jitter.
///
/// **Forever is the important word.** A dropped socket used to be retried from
/// exactly one place — `onDone` — while `onError` cancelled the ping timer,
/// announced the failure and scheduled nothing. That is fine when the network
/// returns before the first retry and fatal when it does not:
///
///   t=0.0  network blinks, socket dies      → onDone → retry queued for t=1
///   t=1.0  retry runs, network still down   → the failure surfaces on onError
///   t=1.0  onError announces it and stops trying
///   t=3.0  network is back. Nobody is trying. The board says "Reconnecting…"
///          until the player kills the app.
///
/// A three-second blackout was therefore *worse* than a thirty-second one,
/// because it guaranteed the single retry landed while still offline. Twenty-one
/// players in one hall on one sagging connection hit it in the same minute, and
/// a round of a real tournament had to be finished on another website.
///
/// So every road out of a live socket now leads back to a retry, the delay is
/// jittered (twenty-one phones reconnecting on the same tick is its own small
/// outage), and a synchronous failure to even open the socket is caught rather
/// than thrown into an unwatched future.
///
/// Sends application-level pings every 30 s to prevent proxy timeouts (Fly.io
/// drops idle WebSocket connections after ~60 s).
class ChessWsClient {
  final String gameId;

  /// Resolves the auth token FRESH on every (re)connect. Reading it per-attempt
  /// (instead of capturing one string) fixes two real bugs: a deep-link/push
  /// that opened the game with an empty token (→ server 4001 → reconnect loop),
  /// and a long game where the captured token expired after ~60 min while the
  /// socket kept reconnecting with the dead token. The background 401 refresh
  /// keeps storage's token current, so each reconnect picks up the latest.
  final Future<String?> Function() tokenProvider;

  /// How a channel is opened. Replaced in tests, which have no network.
  static WebSocketChannel Function(Uri uri) connector =
      (uri) => IOWebSocketChannel.connect(uri);

  /// The wait between attempts. Replaced in tests so they do not sleep.
  static Future<void> Function(Duration d) retryDelay = Future<void>.delayed;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  StreamController<Map<String, dynamic>>? _controller;
  Timer? _pingTimer;
  bool _disposed = false;
  int _reconnectDelay = 1; // seconds
  bool _reconnectPending = false;
  final Random _rng = Random();

  ChessWsClient({required this.gameId, required this.tokenProvider});

  Stream<Map<String, dynamic>> get messages {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  Future<void> connect() async {
    if (_disposed) return;
    _cancelPingTimer();

    // Silence the previous socket before opening another. Without this a late
    // onDone from the dead one queues a second reconnect and the player ends up
    // with two sockets racing to apply the same moves.
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {/* already gone */}

    final token = (await tokenProvider()) ?? '';
    if (_disposed) return;

    final uri = Uri.parse('${ApiConstants.chessGameWs(gameId)}?token=$token');
    try {
      _channel = connector(uri);
      _sub = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      _startPingTimer();
    } catch (e) {
      // Opening the socket can fail immediately — no route to host while the
      // radio is still down is the ordinary case here. Thrown from inside a
      // delayed callback it would land in no one's hands and end the retries.
      _controller?.add({'type': 'connection_error', 'message': e.toString()});
      _scheduleReconnect();
    }
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
    // The line this class exists for. An error is a dead socket like any other,
    // and a dead socket must always lead back to a retry.
    _scheduleReconnect();
  }

  void _onDone() {
    _cancelPingTimer();
    if (_disposed) return;
    _controller?.add({'type': 'disconnected'});
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectPending) return;
    // onError and onDone both fire for the same drop. One retry, not two.
    _reconnectPending = true;

    // Jitter: twenty-one phones in one hall lose the same access point at the
    // same instant, and reconnecting on the same tick makes them each other's
    // outage. Spread the herd across the second.
    final wait = Duration(
      milliseconds: _reconnectDelay * 1000 + 100 + _rng.nextInt(400),
    );
    _reconnectDelay = (_reconnectDelay * 2).clamp(1, 30);

    retryDelay(wait).then((_) {
      _reconnectPending = false;
      if (_disposed) return;
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
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _controller?.close();
    _channel = null;
    _controller = null;
  }
}
