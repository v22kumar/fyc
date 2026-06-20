import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';
import '../../domain/entities/chess_game.dart';
import 'game_event.dart';
import 'game_state.dart';

class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc() : super(const GameIdle()) {
    on<StartLocalGame>(_onStartLocal);
    on<MakeMove>(_onMakeMove);
    on<Resign>(_onResign);
    on<AcceptDraw>(_onAcceptDraw);
    on<FlipBoard>(_onFlip);
    on<NewGame>(_onNewGame);
  }

  void _onStartLocal(StartLocalGame event, Emitter<GameState> emit) {
    final engine = bishop.Game(variant: bishop.Variant.standard());
    emit(GameInProgress(
      engine: engine,
      boardState: engine.squaresState(Squares.white),
      orientation: Squares.white,
      whiteName: event.whiteName,
      blackName: event.blackName,
      moveSans: [],
      isWhiteTurn: true,
    ));
  }

  void _onMakeMove(MakeMove event, Emitter<GameState> emit) {
    final s = state;
    if (s is! GameInProgress) return;

    final success = s.engine.makeSquaresMove(event.move);
    if (!success) return;

    final newSans = List<String>.from(s.moveSans)..add(s.engine.history.last.meta?.san ?? '');
    final isWhiteTurn = s.engine.turn == bishop.Squares.white;

    // Check terminal states
    if (s.engine.inCheckmate) {
      emit(GameOver(
        result: isWhiteTurn ? GameResult.blackWins : GameResult.whiteWins,
        whiteName: s.whiteName,
        blackName: s.blackName,
        moveSans: newSans,
        finalFen: s.engine.fen,
      ));
      return;
    }
    if (s.engine.inStalemate) {
      emit(GameOver(
        result: GameResult.draw,
        drawReason: DrawReason.stalemate,
        whiteName: s.whiteName,
        blackName: s.blackName,
        moveSans: newSans,
        finalFen: s.engine.fen,
      ));
      return;
    }
    if (s.engine.insufficientMaterial) {
      emit(GameOver(
        result: GameResult.draw,
        drawReason: DrawReason.insufficientMaterial,
        whiteName: s.whiteName,
        blackName: s.blackName,
        moveSans: newSans,
        finalFen: s.engine.fen,
      ));
      return;
    }

    emit(s.copyWith(
      boardState: s.engine.squaresState(s.orientation),
      moveSans: newSans,
      isWhiteTurn: isWhiteTurn,
    ));
  }

  void _onResign(Resign event, Emitter<GameState> emit) {
    final s = state;
    if (s is! GameInProgress) return;
    emit(GameOver(
      result: event.whiteResigns ? GameResult.blackWins : GameResult.whiteWins,
      whiteName: s.whiteName,
      blackName: s.blackName,
      moveSans: s.moveSans,
      finalFen: s.engine.fen,
    ));
  }

  void _onAcceptDraw(AcceptDraw event, Emitter<GameState> emit) {
    final s = state;
    if (s is! GameInProgress) return;
    emit(GameOver(
      result: GameResult.draw,
      drawReason: DrawReason.agreement,
      whiteName: s.whiteName,
      blackName: s.blackName,
      moveSans: s.moveSans,
      finalFen: s.engine.fen,
    ));
  }

  void _onFlip(FlipBoard event, Emitter<GameState> emit) {
    final s = state;
    if (s is! GameInProgress) return;
    final newOrientation = s.orientation == Squares.white ? Squares.black : Squares.white;
    emit(s.copyWith(
      orientation: newOrientation,
      boardState: s.engine.squaresState(newOrientation),
    ));
  }

  void _onNewGame(NewGame event, Emitter<GameState> emit) {
    emit(const GameIdle());
  }
}
