import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart' hide GameState;
import '../../domain/entities/chess_game.dart';
import '../../data/datasources/chess_remote_datasource.dart';
import 'game_event.dart';
import 'game_state.dart';

class GameBloc extends Bloc<GameEvent, GameState> {
  final ChessRemoteDataSource? _remote; // nullable — null = offline/no auth

  GameBloc({ChessRemoteDataSource? remote})
      : _remote = remote,
        super(const GameIdle()) {
    on<StartLocalGame>(_onStartLocal);
    on<MakeMove>(_onMakeMove);
    on<Resign>(_onResign);
    on<AcceptDraw>(_onAcceptDraw);
    on<FlipBoard>(_onFlip);
    on<NewGame>(_onNewGame);
    on<SubmitGameToBackend>(_onSubmit);
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

    final lastSan = s.engine.history.isNotEmpty
        ? (s.engine.history.last.meta?.prettyName ?? '')
        : '';
    final newSans = List<String>.from(s.moveSans)..add(lastSan);
    final isWhiteTurn = s.engine.turn == bishop.Bishop.white;

    if (s.engine.checkmate) {
      final result = isWhiteTurn ? GameResult.blackWins : GameResult.whiteWins;
      final over = _buildGameOver(s, result, null, newSans);
      emit(over);
      _submitAsync(s, over);
      return;
    }
    if (s.engine.stalemate) {
      final over = _buildGameOver(s, GameResult.draw, DrawReason.stalemate, newSans);
      emit(over);
      _submitAsync(s, over);
      return;
    }
    if (s.engine.insufficientMaterial) {
      final over = _buildGameOver(
          s, GameResult.draw, DrawReason.insufficientMaterial, newSans);
      emit(over);
      _submitAsync(s, over);
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
    final result = event.whiteResigns ? GameResult.blackWins : GameResult.whiteWins;
    final over = _buildGameOver(s, result, null, s.moveSans);
    emit(over);
    _submitAsync(s, over);
  }

  void _onAcceptDraw(AcceptDraw event, Emitter<GameState> emit) {
    final s = state;
    if (s is! GameInProgress) return;
    final over = _buildGameOver(s, GameResult.draw, DrawReason.agreement, s.moveSans);
    emit(over);
    _submitAsync(s, over);
  }

  void _onFlip(FlipBoard event, Emitter<GameState> emit) {
    final s = state;
    if (s is! GameInProgress) return;
    final newOrientation =
        s.orientation == Squares.white ? Squares.black : Squares.white;
    emit(s.copyWith(
      orientation: newOrientation,
      boardState: s.engine.squaresState(newOrientation),
    ));
  }

  void _onNewGame(NewGame event, Emitter<GameState> emit) {
    emit(const GameIdle());
  }

  Future<void> _onSubmit(
      SubmitGameToBackend event, Emitter<GameState> emit) async {
    if (_remote == null) return;
    try {
      await _remote.submitGame(event.payload);
    } catch (_) {
      // Fire-and-forget: silently ignore if offline or auth fails
      // Sprint 2 TODO: queue for retry in local storage
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  GameOver _buildGameOver(
    GameInProgress s,
    GameResult result,
    DrawReason? drawReason,
    List<String> moveSans,
  ) {
    return GameOver(
      result: result,
      drawReason: drawReason,
      whiteName: s.whiteName,
      blackName: s.blackName,
      moveSans: moveSans,
      finalFen: s.engine.fen,
    );
  }

  void _submitAsync(GameInProgress s, GameOver over) {
    if (_remote == null) return;
    final payload = {
      'mode': 'local',
      'time_control': 'untimed',
      'white_name': s.whiteName,
      'black_name': s.blackName,
      'result': _resultKey(over.result),
      if (over.drawReason != null) 'draw_reason': over.drawReason!.name,
      'total_moves': over.moveSans.length,
      'moves': _buildMoveList(s.engine),
    };
    add(SubmitGameToBackend(payload));
  }

  String _resultKey(GameResult r) => switch (r) {
    GameResult.whiteWins => 'white_wins',
    GameResult.blackWins => 'black_wins',
    GameResult.draw => 'draw',
    GameResult.ongoing => 'abandoned',
  };

  List<Map<String, dynamic>> _buildMoveList(bishop.Game engine) {
    final moves = <Map<String, dynamic>>[];
    for (var i = 0; i < engine.history.length; i++) {
      final h = engine.history[i];
      moves.add({
        'ply': i + 1,
        'uci': h.move != null ? engine.toAlgebraic(h.move!) : '',
        'san': h.meta?.prettyName ?? '',
      });
    }
    return moves;
  }
}
