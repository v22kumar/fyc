import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:fyc_connect/features/chess/data/datasources/chess_ws_client.dart';

/// The three seconds that ended a tournament.
///
/// Twenty-one players, round two, one sagging connection in one hall. Games
/// died on a blink of the network and never came back — the boards said
/// "Reconnecting…" until people killed the app, and the quarter-finals onward
/// were played on another website.
///
/// The cause was not the length of the outage. It was that only ONE of the two
/// ways a socket dies led back to a retry:
///
///   onDone  → schedule a retry        ✓
///   onError → announce it and stop    ✗
///
/// So a blackout that outlived the first retry was permanent — and a *short*
/// one was the most reliable way to cause it. The retry fires at one second,
/// fails while the radio is still down, and that failure arrives on onError.
///
/// These tests keep every road open.

class _FakeSink implements WebSocketSink {
  bool closed = false;

  @override
  Future close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  void add(dynamic data) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeChannel implements WebSocketChannel {
  _FakeChannel(this._controller);
  final StreamController _controller;
  final _FakeSink _sink = _FakeSink();

  @override
  Stream get stream => _controller.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Let queued microtasks and the (faked, instant) retry delay settle.
Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late List<Uri> attempts;
  late List<Duration> waits;

  setUp(() {
    attempts = [];
    waits = [];
    // Never sleep in a test; just record what the client asked to wait for.
    ChessWsClient.retryDelay = (d) async => waits.add(d);
  });

  tearDown(() {
    ChessWsClient.connector = (uri) => throw UnimplementedError();
    ChessWsClient.retryDelay = Future<void>.delayed;
  });

  test('a socket that dies with an ERROR is retried', () async {
    // The exact hole. The network is still down when the first retry runs, so
    // the failure surfaces as an error rather than a clean close — and before
    // this fix, that was the end of the game.
    final controllers = <StreamController>[];
    ChessWsClient.connector = (uri) {
      attempts.add(uri);
      final c = StreamController();
      controllers.add(c);
      return _FakeChannel(c);
    };

    final client = ChessWsClient(gameId: 'g1', tokenProvider: () async => 't');
    final seen = <String>[];
    client.messages.listen((m) => seen.add(m['type'] as String));

    await client.connect();
    expect(attempts, hasLength(1), reason: 'the first connection');

    controllers.first.addError(Exception('SocketException: no route to host'));
    await _settle();

    expect(seen, contains('connection_error'));
    expect(attempts.length, greaterThan(1),
        reason: 'an error is a dead socket, and a dead socket must be retried');

    client.dispose();
  });

  test('a connect that throws immediately is retried, not swallowed', () async {
    // While the radio is down, opening the socket fails on the spot. Thrown
    // from inside a delayed callback, that lands in nobody's hands.
    var calls = 0;
    ChessWsClient.connector = (uri) {
      calls++;
      if (calls == 1) {
        throw Exception('SocketException: network is unreachable');
      }
      return _FakeChannel(StreamController());
    };

    final client = ChessWsClient(gameId: 'g1', tokenProvider: () async => 't');
    final seen = <String>[];
    client.messages.listen((m) => seen.add(m['type'] as String));

    await client.connect();
    await _settle();

    expect(seen, contains('connection_error'));
    expect(calls, greaterThan(1), reason: 'it must try again, not give up');

    client.dispose();
  });

  test('one drop reconnects once, though both callbacks fire', () async {
    // onError and onDone both arrive for the same drop. Two retries would mean
    // two live sockets racing to apply the same moves.
    final controllers = <StreamController>[];
    ChessWsClient.connector = (uri) {
      attempts.add(uri);
      final c = StreamController();
      controllers.add(c);
      return _FakeChannel(c);
    };

    final client = ChessWsClient(gameId: 'g1', tokenProvider: () async => 't');
    client.messages.listen((_) {});

    await client.connect();
    final first = controllers.first;

    first.addError(Exception('dropped'));
    await _settle(); // the error is handled and the reconnection happens
    await first.close(); // the dead socket finally closes, as it does in life
    await _settle();

    expect(attempts, hasLength(2),
        reason: 'one drop is one reconnection, not a second racing socket');

    client.dispose();
  });

  test('the wait grows, stays bounded, and is never the same for every phone',
      () async {
    // Twenty-one phones lose the same access point together. Reconnecting on
    // the very same tick makes them each other's outage.
    var calls = 0;
    ChessWsClient.connector = (uri) {
      calls++;
      throw Exception('still down');
    };

    final client = ChessWsClient(gameId: 'g1', tokenProvider: () async => 't');
    client.messages.listen((_) {});

    await client.connect();
    await _settle();

    expect(waits, isNotEmpty);
    expect(calls, greaterThan(1), reason: 'it keeps trying while down');
    for (final w in waits) {
      expect(w.inMilliseconds % 1000, isNot(0),
          reason: 'a herd reconnecting in lockstep is its own outage');
      expect(w.inMilliseconds, lessThanOrEqualTo(31000),
          reason: 'backoff must stay bounded');
    }

    client.dispose();
  });

  test('a disposed client stops trying', () async {
    ChessWsClient.connector = (uri) {
      attempts.add(uri);
      return _FakeChannel(StreamController());
    };
    final client = ChessWsClient(gameId: 'g1', tokenProvider: () async => 't');
    client.messages.listen((_) {});
    await client.connect();
    client.dispose();

    final before = attempts.length;
    await _settle();
    expect(attempts, hasLength(before),
        reason: 'leaving the board must actually leave');
  });
}
