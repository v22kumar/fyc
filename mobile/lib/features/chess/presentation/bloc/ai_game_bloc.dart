import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:squares/squares.dart';
import 'package:stockfish_chess_engine/stockfish_chess_engine.dart';
import 'ai_game_event.dart';
import 'ai_game_state.dart';

class AiGameBloc extends Bloc<AiGameEvent, AiGameState> {
  Stockfish? _stockfish;
  StreamSubscription<String>? _stockfishSub;
  int _depth = 5;
  bool _playerIsWhite = true;

  AiGameBloc() : super(const AiGameIdle()) {
    on<StartAiGame>(_onStart);
    on<MakeAiMove>(_onPlayerMove);
    on<ResignToAi>(_onResign);
    on<NewAiGame>(_onNewGame);
    on<FlipAiBoard>(_onFlip);
    on<_AiBestMove>(_onAiBestMove);
  }

  @override
  Future<void> close() {
    _stockfishSub?.cancel();
    _stockfish?.dispose();
    return super.close();
  }

  // ── Startup ────────────────────────────────────────────────────────────────

  Future<void> _onStart(StartAiGame event, Emitter<AiGameState> emit) async {
    _depth = event.depth;
    _playerIsWhite = event.playerIsWhite;
    emit(const AiGameLoading());

    // Dispose previous instance
    _stockfishSub?.cancel();
    _stockfish?.dispose();
    _stockfish = Stockfish();
    _stockfishSub = _stockfish!.stdout.listen(_onStockfishOutput);

    // Wait for Stockfish to reach ready state (max 10s)
    final readyCompleter = Completer<void>();
    void listener() {
      if (_stockfish!.state.value == StockfishState.ready &&
          !readyCompleter.isCompleted) {
        readyCompleter.complete();
      }
    }
    _stockfish!.state.addListener(listener);
    if (_stockfish!.state.value == StockfishState.ready) {
      readyCompleter.complete();
    }
    await readyCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    _stockfish!.state.removeListener(listener);

    // Configure Stockfish
    _stockfish!.stdin = 'uci';
    _stockfish!.stdin = 'setoption name Skill Level value ${event.skill}';
    _stockfish!.stdin = 'isready';

    // Build initial game
    final engine = bishop.Game(variant: bishop.Variant.standard());
    final orientation = event.playerIsWhite ? Squares.white : Squares.black;

    emit(AiGameInProgress(
      engine: engine,
      boardState: engine.squaresState(orientation),
      orientation: orientation,
      playerName: event.playerName,
      aiName: _aiName(event.depth),
      playerIsWhite: event.playerIsWhite,
      moveSans: [],
      isPlayerTurn: event.playerIsWhite, // white always moves first
      isThinking: !event.playerIsWhite,   // AI goes first if player is black
    ));

    // If player is black, trigger AI's first move
    if (!event.playerIsWhite) {
      _requestAiMove(engine);
    }
  }

  void _onStockfishOutput(String line) {
    if (isClosed) return;
    if (line.startsWith('bestmove')) {
      final parts = line.split(' ');
      if (parts.length >= 2 && parts[1] != '(none)') {
        add(_AiBestMove(parts[1]));
      }
    }
  }

  void _requestAiMove(bishop.Game engine) {
    if (_stockfish == null) return;
    _stockfish!.stdin = 'position fen ${engine.fen}';
    _stockfish!.stdin = 'go depth $_depth';
  }

  // ── Player move ────────────────────────────────────────────────────────────

  void _onPlayerMove(MakeAiMove event, Emitter<AiGameState> emit) {
    final s = state;
    if (s is! AiGameInProgress || !s.isPlayerTurn || s.isThinking) return;

    final success = s.engine.makeSquaresMove(event.move);
    if (!success) return;

    final san = s.engine.history.isNotEmpty
        ? (s.engine.history.last.meta?.san ?? '')
        : '';
    final newSans = List<String>.from(s.moveSans)..add(san);

    // Check game over
    final over = _checkGameOver(s.engine, newSans, s, playerJustMoved: true);
    if (over != null) {
      emit(over);
      return;
    }

    emit(s.copyWith(
      boardState: s.engine.squaresState(s.orientation),
      moveSans: newSans,
      isPlayerTurn: false,
      isThinking: true,
    ));

    _requestAiMove(s.engine);
  }

  // ── AI move ────────────────────────────────────────────────────────────────

  void _onAiBestMove(_AiBestMove event, Emitter<AiGameState> emit) {
    final s = state;
    if (s is! AiGameInProgress) return;

    // Find and apply the legal move matching this UCI
    bishop.Move? aiMove;
    for (final m in s.engine.generateLegalMoves()) {
      if (m.algebraic() == event.uci) {
        aiMove = m;
        break;
      }
    }
    if (aiMove == null) return;

    s.engine.makeMove(aiMove);

    final san = s.engine.history.isNotEmpty
        ? (s.engine.history.last.meta?.san ?? '')
        : '';
    final newSans = List<String>.from(s.moveSans)..add(san);

    final over = _checkGameOver(s.engine, newSans, s, playerJustMoved: false);
    if (over != null) {
      emit(over);
      return;
    }

    emit(s.copyWith(
      boardState: s.engine.squaresState(s.orientation),
      moveSans: newSans,
      isPlayerTurn: true,
      isThinking: false,
    ));
  }

  // ── Other events ───────────────────────────────────────────────────────────

  void _onResign(ResignToAi event, Emitter<AiGameState> emit) {
    final s = state;
    if (s is! AiGameInProgress) return;
    emit(AiGameOver(
      result: 'ai_wins',
      reason: 'resignation',
      playerName: s.playerName,
      aiName: s.aiName,
      moveSans: s.moveSans,
    ));
  }

  void _onNewGame(NewAiGame event, Emitter<AiGameState> emit) {
    _stockfishSub?.cancel();
    _stockfish?.dispose();
    _stockfish = null;
    emit(const AiGameIdle());
  }

  void _onFlip(FlipAiBoard event, Emitter<AiGameState> emit) {
    final s = state;
    if (s is! AiGameInProgress) return;
    final newOri = s.orientation == Squares.white ? Squares.black : Squares.white;
    emit(s.copyWith(
      orientation: newOri,
      boardState: s.engine.squaresState(newOri),
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  AiGameOver? _checkGameOver(
    bishop.Game engine,
    List<String> sans,
    AiGameInProgress s, {
    required bool playerJustMoved,
  }) {
    if (engine.inCheckmate) {
      return AiGameOver(
        result: playerJustMoved ? 'player_wins' : 'ai_wins',
        reason: 'checkmate',
        playerName: s.playerName,
        aiName: s.aiName,
        moveSans: sans,
      );
    }
    if (engine.inStalemate) {
      return AiGameOver(
        result: 'draw',
        reason: 'stalemate',
        playerName: s.playerName,
        aiName: s.aiName,
        moveSans: sans,
      );
    }
    if (engine.insufficientMaterial) {
      return AiGameOver(
        result: 'draw',
        reason: 'insufficient material',
        playerName: s.playerName,
        aiName: s.aiName,
        moveSans: sans,
      );
    }
    return null;
  }

  static String _aiName(int depth) {
    if (depth <= 1) return 'Stockfish (Beginner)';
    if (depth <= 3) return 'Stockfish (Easy)';
    if (depth <= 5) return 'Stockfish (Medium)';
    if (depth <= 8) return 'Stockfish (Hard)';
    return 'Stockfish (Expert)';
  }
}
