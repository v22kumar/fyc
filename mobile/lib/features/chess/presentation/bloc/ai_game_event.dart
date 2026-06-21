import 'package:equatable/equatable.dart';
import 'package:squares/squares.dart';

abstract class AiGameEvent extends Equatable {
  const AiGameEvent();
  @override
  List<Object?> get props => [];
}

class StartAiGame extends AiGameEvent {
  final String playerName;
  final int depth;          // Stockfish search depth (1–20)
  final int skill;          // Stockfish Skill Level option (0–20)
  final bool playerIsWhite; // false = player plays black, AI plays white and moves first

  const StartAiGame({
    required this.playerName,
    required this.depth,
    required this.skill,
    this.playerIsWhite = true,
  });

  @override
  List<Object?> get props => [playerName, depth, skill, playerIsWhite];
}

class MakeAiMove extends AiGameEvent {
  final Move move;
  const MakeAiMove(this.move);
  @override
  List<Object?> get props => [move];
}

class ResignToAi extends AiGameEvent {
  const ResignToAi();
}

class NewAiGame extends AiGameEvent {
  const NewAiGame();
}

class FlipAiBoard extends AiGameEvent {
  const FlipAiBoard();
}

// Internal — dispatched when Stockfish outputs a bestmove line
class _AiBestMove extends AiGameEvent {
  final String uci;
  const _AiBestMove(this.uci);
  @override
  List<Object?> get props => [uci];
}
