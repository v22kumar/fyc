import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:squares/squares.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/online_game_bloc.dart';
import '../bloc/online_game_event.dart';
import '../bloc/online_game_state.dart';
import '../widgets/player_info_bar.dart';
import '../widgets/move_history_panel.dart';

class OnlineGamePage extends StatelessWidget {
  final String gameId;
  const OnlineGamePage({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
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
                    icon: const Icon(Icons.flip, color: Colors.white70),
                    onPressed: () =>
                        context.read<OnlineGameBloc>().add(const FlipOnlineBoard()),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    onSelected: (v) {
                      if (v == 'resign') _confirmResign(context);
                      if (v == 'draw') {
                        context.read<OnlineGameBloc>().add(const SendOfferDraw());
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'draw', child: Text('Offer Draw')),
                      PopupMenuItem(
                        value: 'resign',
                        child: Text('Resign', style: TextStyle(color: Colors.red)),
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
          CircularProgressIndicator(color: AppColors.primaryLight),
          SizedBox(height: 16),
          Text('Connecting…',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildWaiting(OnlineGameWaiting state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('♛', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: AppColors.primaryLight),
          const SizedBox(height: 16),
          const Text(
            'Waiting for opponent…',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'You play as ${state.myColor}',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
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

    // Which player is on top vs bottom depends on orientation (can be flipped)
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

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              // Opponent info + clock (top)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: PlayerInfoBar(
                        name: topIsMe ? myName : oppName,
                        captured: topIsMe ? myCaptured : oppCaptured,
                        isActive: topIsMe ? state.isMyTurn : !state.isMyTurn,
                        isTop: true,
                      ),
                    ),
                    if (state.isTimed)
                      _ChessClock(
                        ms: topTimeMs ?? 0,
                        isActive: topIsMe ? state.isMyTurn : !state.isMyTurn,
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
                      child: BoardWidget(
                        state: state.boardState,
                        onMove: (state.isMyTurn && !state.moveInFlight)
                            ? (move) => context
                                .read<OnlineGameBloc>()
                                .add(SendMove(move))
                            : null,
                        pieceSet: PieceSet.merida(),
                        theme: BoardTheme(
                          lightSquare: const Color(0xFFF0D9B5),
                          darkSquare: const Color(0xFFB58863),
                          selected: AppColors.primaryLight.withOpacity(0.7),
                          lastFrom: AppColors.gold.withOpacity(0.45),
                          lastTo: AppColors.gold.withOpacity(0.45),
                          checkSquare: Colors.red.withOpacity(0.6),
                          hint: AppColors.primaryLight.withOpacity(0.45),
                        ),
                        settings: const BoardSettings(
                          animationDuration: Duration(milliseconds: 180),
                        ),
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

              // My info + clock (bottom)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: PlayerInfoBar(
                        name: myIsBottom ? myName : oppName,
                        captured: myIsBottom ? myCaptured : oppCaptured,
                        isActive: myIsBottom ? state.isMyTurn : !state.isMyTurn,
                      ),
                    ),
                    if (state.isTimed)
                      _ChessClock(
                        ms: bottomTimeMs ?? 0,
                        isActive: myIsBottom ? state.isMyTurn : !state.isMyTurn,
                      ),
                  ],
                ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning,
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

          // Draw offered banner
          if (state.drawOffered)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold),
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
                              backgroundColor: AppColors.gold,
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
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  minimumSize: const Size(200, 52),
                ),
                child: const Text('Back to Chess',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
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
        title: const Text('Resign?'),
        content: const Text('You will forfeit this game.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<OnlineGameBloc>().add(const SendResign());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  List<String> _capturedByWhite(OnlineGameInProgress s) =>
      _expandCounts(s.engine.capturedPieceCounts(bishop.Squares.black));

  List<String> _capturedByBlack(OnlineGameInProgress s) =>
      _expandCounts(s.engine.capturedPieceCounts(bishop.Squares.white));

  List<String> _expandCounts(Map<int, int> counts) {
    const symbols = {1: '♟', 2: '♞', 3: '♝', 4: '♜', 5: '♛'};
    final result = <String>[];
    for (final entry in counts.entries) {
      final sym = symbols[entry.key & 7];
      if (sym != null) result.addAll(List.filled(entry.value, sym));
    }
    return result;
  }
}

// ── Chess clock widget ────────────────────────────────────────────────────────

class _ChessClock extends StatelessWidget {
  final int ms;
  final bool isActive;

  const _ChessClock({required this.ms, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final totalSecs = (ms / 1000).ceil();
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    final label = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final isLow = ms < 30000; // <30 seconds
    final bg = isActive
        ? (isLow ? Colors.red.shade700 : AppColors.primary)
        : AppColors.darkSurface;
    final fg = isActive ? Colors.white : Colors.white38;

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: isActive && isLow
            ? Border.all(color: Colors.red.shade300, width: 1.5)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          fontSize: 16,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ── Result sheet ───────────────────────────────────────────────────────────────

class _OnlineResultSheet extends StatelessWidget {
  final OnlineGameOver state;
  final VoidCallback onClose;

  const _OnlineResultSheet({required this.state, required this.onClose});

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 24),
          Text(
            state.resultLabel,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${state.moveSans.length} moves',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
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
