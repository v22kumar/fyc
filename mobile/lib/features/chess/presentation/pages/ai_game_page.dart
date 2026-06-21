import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../bloc/ai_game_bloc.dart';
import '../bloc/ai_game_event.dart';
import '../bloc/ai_game_state.dart';
import '../widgets/chess_player_card.dart';
import '../widgets/chess_move_bar.dart';

// ── Lichess colour palette ────────────────────────────────────────────────────
const _kBg = Color(0xFF262421);
const _kSurface = Color(0xFF312E2B);
const _kGreen = Color(0xFF4A7C59);
const _kBoardLight = Color(0xFFEEEED2);
const _kBoardDark = Color(0xFF769656);

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

class _AiGamePageState extends State<AiGamePage>
    with SingleTickerProviderStateMixin {
  bool _resultShown = false;
  bool _is3D = false;

  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnim = CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutCubic);

    final name = sl<LocalStorage>().getString('member_name') ?? 'You';
    context.read<AiGameBloc>().add(StartAiGame(
      playerName: name,
      depth: widget.depth,
      skill: widget.skill,
      playerIsWhite: widget.playerIsWhite,
    ));
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _toggle3D() {
    setState(() => _is3D = !_is3D);
    if (_is3D) {
      _flipCtrl.forward();
    } else {
      _flipCtrl.reverse();
    }
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
      backgroundColor: _kBg,
      appBar: _buildAppBar(context),
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _kBg,
      foregroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 44,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: BlocBuilder<AiGameBloc, AiGameState>(
        builder: (context, state) {
          final label = state is AiGameInProgress
              ? state.aiName
              : 'vs Computer';
          return Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.white,
            ),
          );
        },
      ),
      actions: [
        // 3D / 2D toggle
        BlocBuilder<AiGameBloc, AiGameState>(
          builder: (context, state) {
            if (state is! AiGameInProgress) return const SizedBox.shrink();
            return _AppBarBtn(
              label: _is3D ? '2D' : '3D',
              onTap: _toggle3D,
            );
          },
        ),
        // Flip board
        BlocBuilder<AiGameBloc, AiGameState>(
          builder: (context, state) {
            if (state is! AiGameInProgress) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.swap_vert_rounded,
                  color: Colors.white54, size: 22),
              tooltip: 'Flip board',
              onPressed: () =>
                  context.read<AiGameBloc>().add(const FlipAiBoard()),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Loading ─────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: _kGreen,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 16),
          Text('Loading Stockfish…',
              style: TextStyle(
                color: Color(0xFF8B8682),
                fontSize: 15,
              )),
        ],
      ),
    );
  }

  // ── Main game layout ────────────────────────────────────────────────────────

  Widget _buildGame(BuildContext context, AiGameInProgress state) {
    final bottomIsPlayer = state.orientation == Squares.white
        ? state.playerIsWhite
        : !state.playerIsWhite;

    final bottomName = bottomIsPlayer ? state.playerName : state.aiName;
    final topName = bottomIsPlayer ? state.aiName : state.playerName;
    final bottomActive =
        bottomIsPlayer ? state.isPlayerTurn : !state.isPlayerTurn;
    final topActive = !bottomActive;
    final bottomCaptured =
        bottomIsPlayer ? state.capturedByPlayer : state.capturedByAi;
    final topCaptured =
        bottomIsPlayer ? state.capturedByAi : state.capturedByPlayer;
    final topIsAi = bottomIsPlayer;

    return SafeArea(
      child: Column(
        children: [
          // ── Opponent card ────────────────────────────────────────────────
          ChessPlayerCard(
            name: topName,
            isActive: topActive,
            isThinking: state.isThinking && topActive,
            avatarColor: topIsAi ? const Color(0xFF5B4B8A) : _kGreen,
            avatarWidget: topIsAi
                ? const Text('🤖', style: TextStyle(fontSize: 20))
                : null,
            captured: topCaptured,
          ),

          // ── Board ────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AnimatedBuilder(
                    animation: _flipAnim,
                    builder: (context, child) {
                      return Transform(
                        alignment: Alignment.center,
                        transform: _build3DMatrix(_flipAnim.value),
                        child: child,
                      );
                    },
                    child: BoardController(
                      state: state.boardState.board,
                      playState: state.boardState.state,
                      moves: state.boardState.moves,
                      onMove: (state.isPlayerTurn && !state.isThinking)
                          ? (move) =>
                              context.read<AiGameBloc>().add(MakeAiMove(move))
                          : null,
                      pieceSet: PieceSet.merida(),
                      theme: const BoardTheme(
                        lightSquare: _kBoardLight,
                        darkSquare: _kBoardDark,
                        selected: Color(0xFFFFFFAA),
                        check: Color(0xAAFF3333),
                        checkmate: Color(0xAAFF3333),
                        previous: Color(0xAAF6F669),
                        premove: Color(0x99AAD4AA),
                      ),
                      animationDuration: const Duration(milliseconds: 200),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Move bar ─────────────────────────────────────────────────────
          ChessMoveBar(
            moveSans: state.moveSans,
            isThinking: state.isThinking,
            thinkingLabel: state.aiName,
          ),

          // ── Player card ──────────────────────────────────────────────────
          ChessPlayerCard(
            name: bottomName,
            isActive: bottomActive,
            isThinking: false,
            avatarColor:
                bottomIsPlayer ? _kGreen : const Color(0xFF5B4B8A),
            captured: bottomCaptured,
          ),

          // ── Action bar ───────────────────────────────────────────────────
          _ActionBar(
            onTakeBack: (state.moveSans.length >= 2 &&
                    state.isPlayerTurn &&
                    !state.isThinking)
                ? () => context
                    .read<AiGameBloc>()
                    .add(const TakeBackAiMove())
                : null,
            onNewGame: () {
              _resultShown = false;
              context.read<AiGameBloc>().add(const NewAiGame());
              Navigator.pop(context);
            },
            onResign: () => _confirmResign(context),
          ),
        ],
      ),
    );
  }

  // ── Game over ────────────────────────────────────────────────────────────────

  Widget _buildOver(BuildContext context, AiGameOver state) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.resultLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${state.moveSans.length} moves played',
                style: const TextStyle(
                  color: Color(0xFF8B8682),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _resultShown = false;
                    context.read<AiGameBloc>().add(const NewAiGame());
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'New Game',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Resign dialog ──────────────────────────────────────────────────────────

  void _confirmResign(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Resign?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Forfeit this game to ${(context.read<AiGameBloc>().state is AiGameInProgress) ? (context.read<AiGameBloc>().state as AiGameInProgress).aiName : "Stockfish"}?',
          style: const TextStyle(color: Color(0xFF8B8682)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8B8682)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AiGameBloc>().add(const ResignToAi());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Resign',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3D perspective matrix ──────────────────────────────────────────────────

  Matrix4 _build3DMatrix(double t) {
    final m = Matrix4.identity();
    if (t <= 0) return m;

    // Tilt: rotate X axis + slight Y rotation for depth illusion
    final tiltX = t * (math.pi / 8);   // max ~22.5° tilt back
    final tiltY = t * (math.pi / 48);  // subtle lateral angle

    // Apply perspective
    m.setEntry(3, 2, -0.0015 * t);
    m.rotateX(tiltX);
    m.rotateY(tiltY);

    // Scale down slightly so board fits while tilted
    final scale = 1.0 - 0.08 * t;
    m.scale(scale, scale, 1.0);

    return m;
  }
}

// ── App bar button ──────────────────────────────────────────────────────────

class _AppBarBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AppBarBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF4A4440)),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFBDB9B4),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Bottom action bar ──────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final VoidCallback? onTakeBack;
  final VoidCallback onNewGame;
  final VoidCallback onResign;

  const _ActionBar({
    required this.onTakeBack,
    required this.onNewGame,
    required this.onResign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF1E1B18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionBtn(
            icon: Icons.undo_rounded,
            label: 'Take Back',
            onTap: onTakeBack,
            disabled: onTakeBack == null,
          ),
          _ActionBtn(
            icon: Icons.add_rounded,
            label: 'New Game',
            onTap: onNewGame,
          ),
          _ActionBtn(
            icon: Icons.flag_rounded,
            label: 'Resign',
            onTap: onResign,
            color: Colors.red[400],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;
  final Color? color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled
        ? const Color(0xFF4A4440)
        : (color ?? const Color(0xFFBDB9B4));
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: effectiveColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Result bottom sheet ────────────────────────────────────────────────────

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
    final resultColor = isDraw
        ? const Color(0xFF8B8682)
        : (playerWon ? _kGreen : Colors.red[400]!);

    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF4A4440),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(
            state.resultLabel,
            style: TextStyle(
              color: resultColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${state.moveSans.length} moves',
            style: const TextStyle(
              color: Color(0xFF8B8682),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B8682),
                    side: const BorderSide(color: Color(0xFF4A4440)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Review'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onPlayAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Play Again',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
