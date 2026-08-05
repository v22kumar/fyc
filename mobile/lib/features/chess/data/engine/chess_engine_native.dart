/// Real Stockfish, used wherever `dart:ffi` exists — Android, iOS, desktop.
///
/// Selected by the conditional export in chess_engine.dart. Nothing else in the
/// app may import `stockfish_chess_engine` directly, or the web build breaks
/// again.
export 'package:stockfish_chess_engine/stockfish_chess_engine.dart'
    show Stockfish;
export 'package:stockfish_chess_engine/stockfish_chess_engine_state.dart'
    show StockfishState;

/// Play-vs-computer is available on this platform.
const bool isEngineAvailable = true;
