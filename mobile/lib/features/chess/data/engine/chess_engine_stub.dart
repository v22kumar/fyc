import 'dart:async';

import 'package:flutter/foundation.dart';

/// Stand-in for Stockfish on platforms without `dart:ffi` — currently the web.
///
/// It mirrors the real API exactly so the calling code needs no platform
/// branches, and it settles immediately into [StockfishState.error]. Callers
/// that respect [isEngineAvailable] never construct it; if one slips through,
/// the engine simply reports that it could not start, which the bloc already
/// handles as a normal failure rather than a crash.
enum StockfishState { disposed, error, ready, starting }

class Stockfish {
  Stockfish() {
    // Report failure on the next microtask rather than synchronously, so a
    // listener attached straight after construction still observes the change.
    scheduleMicrotask(() => _state.value = StockfishState.error);
  }

  final ValueNotifier<StockfishState> _state =
      ValueNotifier<StockfishState>(StockfishState.starting);
  final StreamController<String> _stdout = StreamController<String>.broadcast();
  final StreamController<String> _stderr = StreamController<String>.broadcast();

  ValueListenable<StockfishState> get state => _state;

  Stream<String> get stdout => _stdout.stream;

  Stream<String> get stderr => _stderr.stream;

  /// Swallowed: there is no engine to receive UCI commands.
  set stdin(String line) {}

  void dispose() {
    _state.value = StockfishState.disposed;
    _stdout.close();
    _stderr.close();
    _state.dispose();
  }
}

/// Play-vs-computer is not available on this platform.
const bool isEngineAvailable = false;
