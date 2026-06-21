import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart' hide GameState;
import '../../../../core/theme/app_theme.dart';
import '../bloc/game_bloc.dart';
import '../bloc/game_event.dart';
import '../bloc/game_state.dart';
import '../widgets/player_info_bar.dart';
import '../widgets/move_history_panel.dart';
import '../widgets/game_result_sheet.dart';

class LocalGamePage extends StatefulWidget {
  final String whiteName;
  final String blackName;

  const LocalGamePage({
    super.key,
    required this.whiteName,
    required this.blackName,
  });

  @override
  State<LocalGamePage> createState() => _LocalGamePageState();
}

class _LocalGamePageState extends State<LocalGamePage> {
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    context.read<GameBloc>().add(StartLocalGame(
      whiteName: widget.whiteName,
      blackName: widget.blackName,
    ));
  }

  void _showResultSheet(BuildContext context, GameOver state) {
    if (_resultShown) return;
    _resultShown = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameResultSheet(
        state: state,
        onNewGame: () {
          Navigator.pop(context);
          _resultShown = false;
          context.read<GameBloc>().add(const NewGame());
          Navigator.pop(context); // back to chess home
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Local Game',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          BlocBuilder<GameBloc, GameState>(
            builder: (context, state) {
              if (state is! GameInProgress) return const SizedBox.shrink();
              return Row(
                children: [
                  // Flip board
                  IconButton(
                    icon: const Icon(Icons.flip, color: Colors.white70),
                    tooltip: 'Flip board',
                    onPressed: () => context.read<GameBloc>().add(const FlipBoard()),
                  ),
                  // Resign
                  IconButton(
                    icon: const Icon(Icons.flag_outlined, color: Colors.white70),
                    tooltip: 'Resign',
                    onPressed: () => _confirmResign(context, state),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<GameBloc, GameState>(
        listener: (context, state) {
          if (state is GameOver) _showResultSheet(context, state);
          if (state is GameIdle) _resultShown = false;
        },
        builder: (context, state) {
          if (state is GameInProgress) return _buildGame(context, state);
          if (state is GameOver) return _buildGameOver(context, state);
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryLight),
          );
        },
      ),
    );
  }

  Widget _buildGame(BuildContext context, GameInProgress state) {
    final isWhiteTurn = state.isWhiteTurn;
    final bottomIsWhite = state.orientation == Squares.white;

    // Who is shown at bottom (current player from board orientation POV)
    final bottomName = bottomIsWhite ? state.whiteName : state.blackName;
    final topName = bottomIsWhite ? state.blackName : state.whiteName;
    final bottomActive = bottomIsWhite ? isWhiteTurn : !isWhiteTurn;
    final topActive = !bottomActive;
    final bottomCaptured = bottomIsWhite ? state.capturedByWhite : state.capturedByBlack;
    final topCaptured = bottomIsWhite ? state.capturedByBlack : state.capturedByWhite;

    return SafeArea(
      child: Column(
        children: [
          // Top player info
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: PlayerInfoBar(
              name: topName,
              captured: topCaptured,
              isActive: topActive,
              isTop: true,
            ),
          ),

          // Chess board (expands to fill available space)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: BoardController(
                    state: state.boardState.board,
                    playState: state.boardState.state,
                    moves: state.boardState.moves,
                    onMove: (move) =>
                        context.read<GameBloc>().add(MakeMove(move)),
                    pieceSet: PieceSet.merida(),
                    theme: BoardTheme(
                      lightSquare: const Color(0xFFF0D9B5),
                      darkSquare: const Color(0xFFB58863),
                      selected: AppColors.primaryLight.withOpacity(0.7),
                      check: Colors.red.withOpacity(0.6),
                      checkmate: Colors.red.withOpacity(0.6),
                      previous: AppColors.gold.withOpacity(0.45),
                      premove: AppColors.primaryLight.withOpacity(0.45),
                    ),
                    animationDuration: const Duration(milliseconds: 180),
                  ),
                ),
              ),
            ),
          ),

          // Move history
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: MoveHistoryPanel(moveSans: state.moveSans),
          ),

          // Bottom player info
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: PlayerInfoBar(
              name: bottomName,
              captured: bottomCaptured,
              isActive: bottomActive,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver(BuildContext context, GameOver state) {
    // Board is still visible behind the sheet; show a frozen board
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                state.resultLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                _resultShown = false;
                context.read<GameBloc>().add(const NewGame());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                ),
              ),
              child: const Text('New Game', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmResign(BuildContext context, GameInProgress state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resign?'),
        content: Text(
          '${state.currentPlayerName} will forfeit this game.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<GameBloc>().add(
                Resign(whiteResigns: state.isWhiteTurn),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }
}
