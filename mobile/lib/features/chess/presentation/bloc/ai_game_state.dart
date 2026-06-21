import 'package:equatable/equatable.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';

abstract class AiGameState extends Equatable {
  const AiGameState();
  @override
  List<Object?> get props => [];
}

class AiGameIdle extends AiGameState {
  const AiGameIdle();
}

class AiGameLoading extends AiGameState {
  const AiGameLoading();
}

class AiGameInProgress extends AiGameState {
  final bishop.Game engine;
  final BoardState boardState;
  final int orientation;      // Squares.white | Squares.black (player's POV)
  final String playerName;
  final String aiName;        // e.g. "Stockfish (Medium)"
  final bool playerIsWhite;
  final List<String> moveSans;
  final bool isPlayerTurn;
  final bool isThinking;      // AI computing best move

  const AiGameInProgress({
    required this.engine,
    required this.boardState,
    required this.orientation,
    required this.playerName,
    required this.aiName,
    required this.playerIsWhite,
    required this.moveSans,
    required this.isPlayerTurn,
    this.isThinking = false,
  });

  List<String> get capturedByPlayer {
    final side = playerIsWhite ? bishop.Squares.black : bishop.Squares.white;
    return _expandCounts(engine.capturedPieceCounts(side));
  }

  List<String> get capturedByAi {
    final side = playerIsWhite ? bishop.Squares.white : bishop.Squares.black;
    return _expandCounts(engine.capturedPieceCounts(side));
  }

  List<String> _expandCounts(Map<int, int> counts) {
    const symbols = {1: '♟', 2: '♞', 3: '♝', 4: '♜', 5: '♛'};
    final result = <String>[];
    for (final entry in counts.entries) {
      final sym = symbols[entry.key & 7];
      if (sym != null) result.addAll(List.filled(entry.value, sym));
    }
    return result;
  }

  AiGameInProgress copyWith({
    bishop.Game? engine,
    BoardState? boardState,
    int? orientation,
    List<String>? moveSans,
    bool? isPlayerTurn,
    bool? isThinking,
  }) {
    return AiGameInProgress(
      engine: engine ?? this.engine,
      boardState: boardState ?? this.boardState,
      orientation: orientation ?? this.orientation,
      playerName: playerName,
      aiName: aiName,
      playerIsWhite: playerIsWhite,
      moveSans: moveSans ?? this.moveSans,
      isPlayerTurn: isPlayerTurn ?? this.isPlayerTurn,
      isThinking: isThinking ?? this.isThinking,
    );
  }

  @override
  List<Object?> get props => [boardState, moveSans, isPlayerTurn, isThinking];
}

class AiGameOver extends AiGameState {
  final String result;    // "player_wins" | "ai_wins" | "draw"
  final String reason;    // "checkmate" | "stalemate" | "resignation" | etc.
  final String playerName;
  final String aiName;
  final List<String> moveSans;

  const AiGameOver({
    required this.result,
    required this.reason,
    required this.playerName,
    required this.aiName,
    required this.moveSans,
  });

  String get resultLabel {
    return switch (result) {
      'player_wins' => '$playerName wins — $reason',
      'ai_wins' => '$aiName wins — $reason',
      _ => 'Draw — $reason',
    };
  }

  @override
  List<Object?> get props => [result, reason, playerName, aiName];
}
