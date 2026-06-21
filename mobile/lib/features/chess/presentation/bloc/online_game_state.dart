import 'package:equatable/equatable.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';

abstract class OnlineGameState extends Equatable {
  const OnlineGameState();
  @override
  List<Object?> get props => [];
}

class OnlineGameConnecting extends OnlineGameState {
  const OnlineGameConnecting();
}

class OnlineGameWaiting extends OnlineGameState {
  final String myColor;
  const OnlineGameWaiting({required this.myColor});
  @override
  List<Object?> get props => [myColor];
}

class OnlineGameInProgress extends OnlineGameState {
  final bishop.Game engine;
  final BoardState boardState;
  final int orientation;         // Squares.white | Squares.black
  final String myColor;          // "white" | "black"
  final String whiteName;
  final String blackName;
  final List<String> moveSans;
  final bool isMyTurn;
  final bool drawOffered;        // opponent offered draw
  final bool moveInFlight;       // we sent a move, waiting for server confirmation
  final bool opponentDisconnected;
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
    this.timeControl = 'untimed',
    this.whiteTimeMs,
    this.blackTimeMs,
  });

  bool get isTimed => timeControl != 'untimed' && whiteTimeMs != null;

  OnlineGameInProgress copyWith({
    bishop.Game? engine,
    BoardState? boardState,
    int? orientation,
    List<String>? moveSans,
    bool? isMyTurn,
    bool? drawOffered,
    bool? moveInFlight,
    bool? opponentDisconnected,
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
      timeControl: timeControl ?? this.timeControl,
      whiteTimeMs: clearWhiteTime ? null : (whiteTimeMs ?? this.whiteTimeMs),
      blackTimeMs: clearBlackTime ? null : (blackTimeMs ?? this.blackTimeMs),
    );
  }

  @override
  List<Object?> get props => [boardState, moveSans, isMyTurn, drawOffered,
                               moveInFlight, opponentDisconnected,
                               whiteTimeMs, blackTimeMs];
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
