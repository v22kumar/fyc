import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../bloc/ai_game_bloc.dart';
import '../bloc/ai_game_event.dart';
import '../bloc/ai_game_state.dart';
import '../widgets/player_info_bar.dart';
import '../widgets/move_history_panel.dart';

class AiGamePage extends StatefulWidget {
  final int depth;
  final int skill;
  final bool playerIsWhite;

  const AiGamePage({
    super.key,
    required this.depth,
    required this.skill,
    this.playerIsWhite = true,
  });

  @override
  State<AiGamePage> createState() => _AiGamePageState();
}

class _AiGamePageState extends State<AiGamePage> {
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    final name = sl<LocalStorage>().getString('member_name') ?? 'You';
    context.read<AiGameBloc>().add(StartAiGame(
      playerName: name,
      depth: widget.depth,
      skill: widget.skill,
      playerIsWhite: widget.playerIsWhite,
    ));
  }

  void _showResult(BuildContext context, AiGameOver state) {
    if (_resultShown) return;
    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AiResultSheet(
          state: state,
          onPlayAgain: () {
            Navigator.pop(context);
            _resultShown = false;
            context.read<AiGameBloc>().add(const NewAiGame());
            Navigator.pop(context);
          },
          onClose: () => Navigator.pop(context),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: BlocBuilder<AiGameBloc, AiGameState>(
          builder: (context, state) {
            if (state is AiGameInProgress) {
              return Text('vs ${state.aiName}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
            }
            return const Text('vs Computer',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
          },
        ),
        actions: [
          BlocBuilder<AiGameBloc, AiGameState>(
            builder: (context, state) {
              if (state is! AiGameInProgress) return const SizedBox.shrink();
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.flip, color: Colors.white70),
                    tooltip: 'Flip board',
                    onPressed: () =>
                        context.read<AiGameBloc>().add(const FlipAiBoard()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flag_outlined, color: Colors.white70),
                    tooltip: 'Resign',
                    onPressed: () => _confirmResign(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<AiGameBloc, AiGameState>(
        listener: (context, state) {
          if (state is AiGameOver) _showResult(context, state);
          if (state is AiGameIdle) _resultShown = false;
        },
        builder: (context, state) {
          if (state is AiGameLoading) return _buildLoading();
          if (state is AiGameInProgress) return _buildGame(context, state);
          if (state is AiGameOver) return _buildOver(context, state);
          return _buildLoading();
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryLight),
          SizedBox(height: 16),
          Text('Loading Stockfish…',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildGame(BuildContext context, AiGameInProgress state) {
    final bottomIsPlayer = state.orientation == Squares.white
        ? state.playerIsWhite
        : !state.playerIsWhite;

    final bottomName = bottomIsPlayer ? state.playerName : state.aiName;
    final topName = bottomIsPlayer ? state.aiName : state.playerName;
    final bottomActive = bottomIsPlayer ? state.isPlayerTurn : !state.isPlayerTurn;
    final topActive = !bottomActive;
    final bottomCaptured = bottomIsPlayer ? state.capturedByPlayer : state.capturedByAi;
    final topCaptured = bottomIsPlayer ? state.capturedByAi : state.capturedByPlayer;

    return SafeArea(
      child: Column(
        children: [
          // Top player (opponent / AI)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: PlayerInfoBar(
                    name: topName,
                    captured: topCaptured,
                    isActive: topActive,
                    isTop: true,
                  ),
                ),
                if (state.isThinking && topActive)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: BoardController(
                    state: state.boardState.board,
                    playState: state.boardState.state,
                    moves: state.boardState.moves,
                    onMove: (state.isPlayerTurn && !state.isThinking)
                        ? (move) =>
                            context.read<AiGameBloc>().add(MakeAiMove(move))
                        : null,
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
                    animationDuration: const Duration(milliseconds: 200),
                  ),
                ),
              ),
            ),
          ),

          // Move history
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: MoveHistoryPanel(moveSans: state.moveSans),
          ),

          // Bottom player (usually the human)
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

  Widget _buildOver(BuildContext context, AiGameOver state) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.resultLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _resultShown = false;
                  context.read<AiGameBloc>().add(const NewAiGame());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  minimumSize: const Size(200, 52),
                ),
                child: const Text('Back',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResign(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resign?'),
        content: const Text('You will forfeit this game to Stockfish.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AiGameBloc>().add(const ResignToAi());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }
}

// ── Result sheet ───────────────────────────────────────────────────────────────

class _AiResultSheet extends StatelessWidget {
  final AiGameOver state;
  final VoidCallback onPlayAgain;
  final VoidCallback onClose;

  const _AiResultSheet({
    required this.state,
    required this.onPlayAgain,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final playerWon = state.result == 'player_wins';
    final isDraw = state.result == 'draw';
    final emoji = isDraw ? '🤝' : (playerWon ? '🏆' : '🤖');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            state.resultLabel,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${state.moveSans.length} moves',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onClose();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusBtn)),
                  ),
                  child: const Text('Review'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onPlayAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusBtn)),
                  ),
                  child: const Text('Play Again',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
