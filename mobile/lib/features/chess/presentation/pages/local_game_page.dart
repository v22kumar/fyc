import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart' hide GameState;
import '../bloc/game_bloc.dart';
import '../bloc/game_event.dart';
import '../bloc/game_state.dart';
import '../widgets/chess_player_card.dart';
import '../widgets/chess_move_bar.dart';
import '../widgets/game_result_sheet.dart';

const _kBg = Color(0xFF262421);
const _kSurface = Color(0xFF312E2B);
const _kGreen = Color(0xFF4A7C59);
const _kBoardLight = Color(0xFFEEEED2);
const _kBoardDark = Color(0xFF769656);

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
          Navigator.pop(context);
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 44,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
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
                  IconButton(
                    icon: const Icon(Icons.swap_vert_rounded,
                        color: Colors.white54, size: 22),
                    tooltip: 'Flip board',
                    onPressed: () =>
                        context.read<GameBloc>().add(const FlipBoard()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flag_rounded,
                        color: Colors.white54, size: 22),
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
            child: CircularProgressIndicator(color: _kGreen),
          );
        },
      ),
    );
  }

  Widget _buildGame(BuildContext context, GameInProgress state) {
    final isWhiteTurn = state.isWhiteTurn;
    final bottomIsWhite = state.orientation == Squares.white;

    final bottomName = bottomIsWhite ? state.whiteName : state.blackName;
    final topName = bottomIsWhite ? state.blackName : state.whiteName;
    final bottomActive = bottomIsWhite ? isWhiteTurn : !isWhiteTurn;
    final topActive = !bottomActive;
    final bottomCaptured =
        bottomIsWhite ? state.capturedByWhite : state.capturedByBlack;
    final topCaptured =
        bottomIsWhite ? state.capturedByBlack : state.capturedByWhite;

    return SafeArea(
      child: Column(
        children: [
          ChessPlayerCard(
            name: topName,
            isActive: topActive,
            avatarColor: _kGreen,
            captured: topCaptured,
          ),

          Expanded(
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
                  theme: const BoardTheme(
                    lightSquare: _kBoardLight,
                    darkSquare: _kBoardDark,
                    selected: Color(0xFFFFFFAA),
                    check: Color(0xAAFF3333),
                    checkmate: Color(0xAAFF3333),
                    previous: Color(0xAAF6F669),
                    premove: Color(0x99AAD4AA),
                  ),
                  animationDuration: const Duration(milliseconds: 180),
                ),
              ),
            ),
          ),

          ChessMoveBar(moveSans: state.moveSans),

          ChessPlayerCard(
            name: bottomName,
            isActive: bottomActive,
            avatarColor: _kGreen,
            captured: bottomCaptured,
          ),

          _LocalActionBar(
            onFlip: () => context.read<GameBloc>().add(const FlipBoard()),
            onResign: () => _confirmResign(context, state),
            onNewGame: () {
              _resultShown = false;
              context.read<GameBloc>().add(const NewGame());
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver(BuildContext context, GameOver state) {
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _resultShown = false;
                    context.read<GameBloc>().add(const NewGame());
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
                  child: const Text('New Game',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResign(BuildContext context, GameInProgress state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resign?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          '${state.currentPlayerName} will forfeit this game.',
          style: const TextStyle(color: Color(0xFF8B8682)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8B8682))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<GameBloc>()
                  .add(Resign(whiteResigns: state.isWhiteTurn));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resign',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _LocalActionBar extends StatelessWidget {
  final VoidCallback onFlip;
  final VoidCallback onResign;
  final VoidCallback onNewGame;

  const _LocalActionBar({
    required this.onFlip,
    required this.onResign,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF1E1B18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Btn(icon: Icons.swap_vert_rounded, label: 'Flip', onTap: onFlip),
          _Btn(icon: Icons.add_rounded, label: 'New Game', onTap: onNewGame),
          _Btn(
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

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _Btn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFFBDB9B4);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: c,
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
