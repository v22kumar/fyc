/// Platform-conditional access to the Stockfish engine.
///
/// `stockfish_chess_engine` is FFI-only, so importing it directly makes the
/// whole app impossible to compile for the web — a single feature (play vs the
/// computer) blocking every other screen from ever being seen in a browser.
///
/// This picks the real engine wherever `dart:ffi` exists (Android, iOS,
/// desktop) and a stub everywhere else. Callers program against one API and
/// check [isEngineAvailable] before offering the feature.
export 'chess_engine_stub.dart' if (dart.library.ffi) 'chess_engine_native.dart';
