import 'package:equatable/equatable.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';

abstract class OnlineGameState extends Equatable {
  const OnlineGameState();
  @override
  List<Object?> get props => [];
}

class OnlineGameConnecting extends OnlineGameState {
  /// True when this is a mid-game reconnect (the socket dropped after play had
  /// started) rather than the very first connect — lets the UI say
  /// "Reconnecting…" instead of "Connecting…".
  final bool reconnecting;
  const OnlineGameConnecting({this.reconnecting = false});
  @override
  List<Object?> get props => [reconnecting];
}

class OnlineGameWaiting extends OnlineGameState {
  final String myColor;
  const OnlineGameWaiting({required this.myColor});
  @override
  List<Object?> get props => [myColor];
}

class OnlineGameInProgress extends OnlineGameState {
  final bishop.Game engine;
  final SquaresState boardState;
  final int orientation;         // Squares.white | Squares.black
  final String myColor;          // "white" | "black"
  final String whiteName;
  final String blackName;
  final List<String> moveSans;
  final bool isMyTurn;
  final bool drawOffered;        // opponent offered draw
  final bool moveInFlight;       // we sent a move, waiting for server confirmation
  final bool opponentDisconnected;
  final bool reconnecting;       // OUR socket dropped; client is auto-reconnecting
  /// The server froze the game (a move could not be durably saved) and an
  /// organizer has been alerted. Moves are refused until it is resolved.
  final bool paused;
  final String timeControl;      // "untimed" | "blitz_5_0" | "rapid_10_0"
  final int? whiteTimeMs;        // null = untimed
  final int? blackTimeMs;

  const OnlineGameInProgress({
    required this.engine,
    required this.boardState,
    required this.orientation,
    required this.myColor,
    required this.whiteName,
    required this.blackName,
    required this.moveSans,
    required this.isMyTurn,
    this.drawOffered = false,
    this.moveInFlight = false,
    this.opponentDisconnected = false,
    this.reconnecting = false,
    this.paused = false,
    this.timeControl = 'untimed',
    this.whiteTimeMs,
    this.blackTimeMs,
  });

  bool get isTimed => timeControl != 'untimed' && whiteTimeMs != null;

  OnlineGameInProgress copyWith({
    bishop.Game? engine,
    SquaresState? boardState,
    int? orientation,
    List<String>? moveSans,
    bool? isMyTurn,
    bool? drawOffered,
    bool? moveInFlight,
    bool? opponentDisconnected,
    bool? reconnecting,
    bool? paused,
    String? timeControl,
    int? whiteTimeMs,
    int? blackTimeMs,
    bool clearWhiteTime = false,
    bool clearBlackTime = false,
  }) {
    return OnlineGameInProgress(
      engine: engine ?? this.engine,
      boardState: boardState ?? this.boardState,
      orientation: orientation ?? this.orientation,
      myColor: myColor,
      whiteName: whiteName,
      blackName: blackName,
      moveSans: moveSans ?? this.moveSans,
      isMyTurn: isMyTurn ?? this.isMyTurn,
      drawOffered: drawOffered ?? this.drawOffered,
      moveInFlight: moveInFlight ?? this.moveInFlight,
      opponentDisconnected: opponentDisconnected ?? this.opponentDisconnected,
      reconnecting: reconnecting ?? this.reconnecting,
      paused: paused ?? this.paused,
      timeControl: timeControl ?? this.timeControl,
      whiteTimeMs: clearWhiteTime ? null : (whiteTimeMs ?? this.whiteTimeMs),
      blackTimeMs: clearBlackTime ? null : (blackTimeMs ?? this.blackTimeMs),
    );
  }

  @override
  List<Object?> get props => [boardState, moveSans, isMyTurn, drawOffered,
                               moveInFlight, opponentDisconnected, reconnecting,
                               paused, whiteTimeMs, blackTimeMs];
}

class OnlineGameOver extends OnlineGameState {
  final String result;   // white_wins | black_wins | draw
  final String reason;   // checkmate | resignation | stalemate | etc.
  final String whiteName;
  final String blackName;
  final List<String> moveSans;

  const OnlineGameOver({
    required this.result,
    required this.reason,
    required this.whiteName,
    required this.blackName,
    required this.moveSans,
  });

  String get resultLabel {
    if (result == 'draw') return 'Draw — $reason';
    final winner = result == 'white_wins' ? whiteName : blackName;
    return '$winner wins — $reason';
  }

  @override
  List<Object?> get props => [result, reason];
}

class OnlineGameError extends OnlineGameState {
  final String message;
  const OnlineGameError(this.message);
  @override
  List<Object?> get props => [message];
}
