import 'package:equatable/equatable.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';

abstract class SpectatorState extends Equatable {
  const SpectatorState();

  @override
  List<Object?> get props => [];
}

class SpectatorConnecting extends SpectatorState {
  const SpectatorConnecting();
}

class SpectatorWatching extends SpectatorState {
  final bishop.Game engine;
  final SquaresState boardState;
  final String whiteName;
  final String blackName;
  final List<String> moveSans;
  final String currentTurn; // "white" | "black"
  final int? whiteTimeMs;
  final int? blackTimeMs;
  final String timeControl;
  final int spectatorCount;

  const SpectatorWatching({
    required this.engine,
    required this.boardState,
    required this.whiteName,
    required this.blackName,
    required this.moveSans,
    required this.currentTurn,
    this.whiteTimeMs,
    this.blackTimeMs,
    required this.timeControl,
    required this.spectatorCount,
  });

  bool get isTimed => timeControl != 'untimed' && whiteTimeMs != null;

  SpectatorWatching copyWith({
    bishop.Game? engine,
    SquaresState? boardState,
    List<String>? moveSans,
    String? currentTurn,
    int? whiteTimeMs,
    int? blackTimeMs,
    String? timeControl,
    int? spectatorCount,
    bool clearWhiteTime = false,
    bool clearBlackTime = false,
  }) {
    return SpectatorWatching(
      engine: engine ?? this.engine,
      boardState: boardState ?? this.boardState,
      whiteName: whiteName,
      blackName: blackName,
      moveSans: moveSans ?? this.moveSans,
      currentTurn: currentTurn ?? this.currentTurn,
      whiteTimeMs: clearWhiteTime ? null : (whiteTimeMs ?? this.whiteTimeMs),
      blackTimeMs: clearBlackTime ? null : (blackTimeMs ?? this.blackTimeMs),
      timeControl: timeControl ?? this.timeControl,
      spectatorCount: spectatorCount ?? this.spectatorCount,
    );
  }

  @override
  List<Object?> get props => [
        boardState,
        moveSans,
        currentTurn,
        whiteTimeMs,
        blackTimeMs,
        spectatorCount,
      ];
}

class SpectatorGameOver extends SpectatorState {
  final String result;
  final String reason;
  final String whiteName;
  final String blackName;
  final List<String> moveSans;

  const SpectatorGameOver({
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
