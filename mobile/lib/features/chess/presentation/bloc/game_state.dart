import 'package:equatable/equatable.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';
import '../../domain/entities/chess_game.dart';

abstract class GameState extends Equatable {
  const GameState();
  @override
  List<Object?> get props => [];
}

class GameIdle extends GameState {
  const GameIdle();
}

class GameInProgress extends GameState {
  final bishop.Game engine;        // authoritative game logic
  final SquaresState boardState;     // squares rendering state
  final int orientation;           // Squares.white or Squares.black (whose POV)
  final String whiteName;
  final String blackName;
  final bool drawOffered;
  final bool isWhiteTurn;
  final List<String> moveSans;

  const GameInProgress({
    required this.engine,
    required this.boardState,
    required this.orientation,
    required this.whiteName,
    required this.blackName,
    required this.moveSans,
    this.drawOffered = false,
    required this.isWhiteTurn,
  });

  String get currentPlayerName => isWhiteTurn ? whiteName : blackName;

  // Pieces captured by white (black's pieces taken)
  List<String> get capturedByWhite {
    return _getCapturedPieces(true);
  }

  List<String> get capturedByBlack {
    return _getCapturedPieces(false);
  }

  List<String> _getCapturedPieces(bool getBlackPieces) {
    if (engine.state.meta == null) return [];
    final Map<String, int> captured = engine.state.capturedPieces();
    final result = <String>[];
    const symbols = {
      'p': '♟', 'P': '♟',
      'n': '♞', 'N': '♞',
      'b': '♝', 'B': '♝',
      'r': '♜', 'R': '♜',
      'q': '♛', 'Q': '♛',
    };
    captured.forEach((key, count) {
      final isBlack = key == key.toLowerCase();
      if (isBlack == getBlackPieces) {
        final sym = symbols[key];
        if (sym != null) {
          result.addAll(List.filled(count, sym));
        }
      }
    });
    return result;
  }

  GameInProgress copyWith({
    bishop.Game? engine,
    SquaresState? boardState,
    int? orientation,
    String? whiteName,
    String? blackName,
    List<String>? moveSans,
    bool? drawOffered,
    bool? isWhiteTurn,
  }) {
    return GameInProgress(
      engine: engine ?? this.engine,
      boardState: boardState ?? this.boardState,
      orientation: orientation ?? this.orientation,
      whiteName: whiteName ?? this.whiteName,
      blackName: blackName ?? this.blackName,
      moveSans: moveSans ?? this.moveSans,
      drawOffered: drawOffered ?? this.drawOffered,
      isWhiteTurn: isWhiteTurn ?? this.isWhiteTurn,
    );
  }

  @override
  List<Object?> get props => [boardState, orientation, moveSans, drawOffered, isWhiteTurn];
}

class GameOver extends GameState {
  final GameResult result;
  final DrawReason? drawReason;
  final String whiteName;
  final String blackName;
  final List<String> moveSans;
  final String finalFen;

  const GameOver({
    required this.result,
    this.drawReason,
    required this.whiteName,
    required this.blackName,
    required this.moveSans,
    required this.finalFen,
  });

  String get resultLabel {
    return switch (result) {
      GameResult.whiteWins => '$whiteName wins',
      GameResult.blackWins => '$blackName wins',
      GameResult.draw => 'Draw${drawReason != null ? ' — ${drawReason!.name}' : ''}',
      GameResult.ongoing => '',
    };
  }

  @override
  List<Object?> get props => [result, whiteName, blackName, moveSans];
}
