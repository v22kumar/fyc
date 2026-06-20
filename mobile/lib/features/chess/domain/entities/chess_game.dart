import 'package:equatable/equatable.dart';

enum GameMode { local, vsAI, online }
enum GameResult { ongoing, whiteWins, blackWins, draw }
enum DrawReason { stalemate, insufficientMaterial, fiftyMoves, repetition, agreement }

class ChessGame extends Equatable {
  final String id;
  final GameMode mode;
  final String whiteName;
  final String blackName;
  final GameResult result;
  final DrawReason? drawReason;
  final List<String> moveSans;   // algebraic notation list for history display
  final String fen;              // current position
  final bool isWhiteTurn;
  final DateTime startedAt;

  const ChessGame({
    required this.id,
    required this.mode,
    required this.whiteName,
    required this.blackName,
    required this.result,
    this.drawReason,
    required this.moveSans,
    required this.fen,
    required this.isWhiteTurn,
    required this.startedAt,
  });

  bool get isOver => result != GameResult.ongoing;

  String get resultLabel {
    return switch (result) {
      GameResult.whiteWins => '$whiteName wins',
      GameResult.blackWins => '$blackName wins',
      GameResult.draw => 'Draw${drawReason != null ? ' (${drawReason!.name})' : ''}',
      GameResult.ongoing => '',
    };
  }

  @override
  List<Object?> get props => [id, result, fen, moveSans, isWhiteTurn];
}
