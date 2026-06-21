import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';
import '../bloc/online_game_bloc.dart';
import '../bloc/online_game_event.dart';
import '../bloc/online_game_state.dart';
import '../widgets/chess_player_card.dart';
import '../widgets/chess_move_bar.dart';

const _kBg = Color(0xFF262421);
const _kSurface = Color(0xFF312E2B);
const _kGreen = Color(0xFF4A7C59);
const _kBoardLight = Color(0xFFEEEED2);
const _kBoardDark = Color(0xFF769656);

class OnlineGamePage extends StatelessWidget {
  final String gameId;
  const OnlineGamePage({super.key, required this.gameId});

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
        title: BlocBuilder<OnlineGameBloc, OnlineGameState>(
          builder: (context, state) {
            if (state is OnlineGameInProgress) {
              final opp = state.myColor == 'white'
                  ? state.blackName
                  : state.whiteName;
              return Text(
                'vs $opp',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              );
            }
            return const Text('Online Game',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
          },
        ),
        actions: [
          BlocBuilder<OnlineGameBloc, OnlineGameState>(
            builder: (context, state) {
              if (state is! OnlineGameInProgress) return const SizedBox.shrink();
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.swap_vert_rounded,
                        color: Colors.white54, size: 22),
                    onPressed: () =>
                        context.read<OnlineGameBloc>().add(const FlipOnlineBoard()),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white54, size: 22),
                    color: _kSurface,
                    onSelected: (v) {
                      if (v == 'resign') _confirmResign(context);
                      if (v == 'draw') {
                        context
                            .read<OnlineGameBloc>()
                            .add(const SendOfferDraw());
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'draw',
                        child: Text('Offer Draw',
                            style: TextStyle(color: Colors.white)),
                      ),
                      PopupMenuItem(
                        value: 'resign',
                        child: Text('Resign',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<OnlineGameBloc, OnlineGameState>(
        listener: (context, state) {
          if (state is OnlineGameOver) _showResult(context, state);
        },
        builder: (context, state) {
          if (state is OnlineGameConnecting) return _buildConnecting();
          if (state is OnlineGameWaiting) return _buildWaiting(state);
          if (state is OnlineGameInProgress) return _buildGame(context, state);
          if (state is OnlineGameOver) return _buildOver(context, state);
          return _buildConnecting();
        },
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────

  Widget _buildConnecting() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _kGreen),
          SizedBox(height: 16),
          Text('Connecting…',
              style: TextStyle(color: Color(0xFF8B8682), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildWaiting(OnlineGameWaiting state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('♛', style: TextStyle(fontSize: 64, color: _kGreen)),
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: _kGreen),
          const SizedBox(height: 16),
          const Text(
            'Waiting for opponent…',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'You play as ${state.myColor}',
            style: const TextStyle(color: Color(0xFF8B8682), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGame(BuildContext context, OnlineGameInProgress state) {
    final isWhite = state.myColor == 'white';
    final myName = isWhite ? state.whiteName : state.blackName;
    final oppName = isWhite ? state.blackName : state.whiteName;
    final myCaptured = isWhite
        ? _capturedByWhite(state)
        : _capturedByBlack(state);
    final oppCaptured = isWhite
        ? _capturedByBlack(state)
        : _capturedByWhite(state);

    final myIsBottom = state.orientation == Squares.white
        ? state.myColor == 'white'
        : state.myColor == 'black';
    final topIsMe = !myIsBottom;
    final topTimeMs = topIsMe
        ? (isWhite ? state.whiteTimeMs : state.blackTimeMs)
        : (isWhite ? state.blackTimeMs : state.whiteTimeMs);
    final bottomTimeMs = myIsBottom
        ? (isWhite ? state.whiteTimeMs : state.blackTimeMs)
        : (isWhite ? state.blackTimeMs : state.whiteTimeMs);
    final topActive = topIsMe ? state.isMyTurn : !state.isMyTurn;
    final bottomActive = myIsBottom ? state.isMyTurn : !state.isMyTurn;

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              // Opponent card + clock
              _PlayerRow(
                name: topIsMe ? myName : oppName,
                captured: topIsMe ? myCaptured : oppCaptured,
                isActive: topActive,
                timeMs: state.isTimed ? topTimeMs : null,
              ),

              // Board
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: BoardController(
                      state: state.boardState.board,
                      playState: state.boardState.state,
                      moves: state.boardState.moves,
                      onMove: (state.isMyTurn && !state.moveInFlight)
                          ? (move) => context
                              .read<OnlineGameBloc>()
                              .add(SendMove(move))
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
                      animationDuration: const Duration(milliseconds: 180),
                    ),
                  ),
                ),
              ),

              // Move bar
              ChessMoveBar(moveSans: state.moveSans),

              // My card + clock
              _PlayerRow(
                name: myIsBottom ? myName : oppName,
                captured: myIsBottom ? myCaptured : oppCaptured,
                isActive: bottomActive,
                timeMs: state.isTimed ? bottomTimeMs : null,
              ),

              // Online action bar
              _OnlineActionBar(
                onResign: () => _confirmResign(context),
                onDraw: () => context
                    .read<OnlineGameBloc>()
                    .add(const SendOfferDraw()),
                onFlip: () => context
                    .read<OnlineGameBloc>()
                    .add(const FlipOnlineBoard()),
              ),
            ],
          ),

          // Opponent disconnected banner
          if (state.opponentDisconnected)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB45309),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Opponent disconnected — waiting 60s',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Draw offer banner
          if (state.drawOffered)
            Positioned(
              bottom: 70,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4AF37)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Opponent offers a draw',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context
                                .read<OnlineGameBloc>()
                                .add(const SendDeclineDraw()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context
                                .read<OnlineGameBloc>()
                                .add(const SendAcceptDraw()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOver(BuildContext context, OnlineGameOver state) {
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
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Back to Chess',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showResult(BuildContext context, OnlineGameOver state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _OnlineResultSheet(
          state: state,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    });
  }

  void _confirmResign(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resign?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('You will forfeit this game.',
            style: TextStyle(color: Color(0xFF8B8682))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF8B8682)))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<OnlineGameBloc>().add(const SendResign());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resign',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  List<String> _capturedByWhite(OnlineGameInProgress s) =>
      _getCapturedPieces(s.engine, true);

  List<String> _capturedByBlack(OnlineGameInProgress s) =>
      _getCapturedPieces(s.engine, false);

  List<String> _getCapturedPieces(bishop.Game engine, bool getBlackPieces) {
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
        if (sym != null) result.addAll(List.filled(count, sym));
      }
    });
    return result;
  }
}

// ── Player row (card + clock) ───────────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  final String name;
  final List<String> captured;
  final bool isActive;
  final int? timeMs;

  const _PlayerRow({
    required this.name,
    required this.captured,
    required this.isActive,
    this.timeMs,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        ChessPlayerCard(
          name: name,
          isActive: isActive,
          avatarColor: _kGreen,
          captured: captured,
        ),
        if (timeMs != null)
          Positioned(
            right: 14,
            child: _ChessClock(ms: timeMs!, isActive: isActive),
          ),
      ],
    );
  }
}

// ── Chess clock ─────────────────────────────────────────────────────────────

class _ChessClock extends StatelessWidget {
  final int ms;
  final bool isActive;

  const _ChessClock({required this.ms, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final totalSecs = (ms / 1000).ceil();
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    final label =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final isLow = ms < 30000;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? (isLow ? Colors.red.shade800 : _kGreen)
            : const Color(0xFF1E1B18),
        borderRadius: BorderRadius.circular(8),
        border: isActive && isLow
            ? Border.all(color: Colors.red.shade400, width: 1.5)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : const Color(0xFF6B6762),
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          fontSize: 15,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ── Online action bar ────────────────────────────────────────────────────────

class _OnlineActionBar extends StatelessWidget {
  final VoidCallback onResign;
  final VoidCallback onDraw;
  final VoidCallback onFlip;

  const _OnlineActionBar({
    required this.onResign,
    required this.onDraw,
    required this.onFlip,
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
          _Btn(
            icon: Icons.handshake_outlined,
            label: 'Draw',
            onTap: onDraw,
            color: const Color(0xFFD4AF37),
          ),
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

// ── Result sheet ──────────────────────────────────────────────────────────────

class _OnlineResultSheet extends StatelessWidget {
  final OnlineGameOver state;
  final VoidCallback onClose;

  const _OnlineResultSheet({required this.state, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF4A4440),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            state.resultLabel,
            style: const TextStyle(
              color: _kGreen,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${state.moveSans.length} moves',
            style: const TextStyle(color: Color(0xFF8B8682), fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onClose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Back to Chess',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
