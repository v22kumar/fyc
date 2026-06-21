import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';
import '../bloc/spectator_bloc.dart';
import '../bloc/spectator_state.dart';
import '../widgets/chess_player_card.dart';
import '../widgets/chess_move_bar.dart';

const _kBg = Color(0xFF262421);
const _kSurface = Color(0xFF312E2B);
const _kGreen = Color(0xFF4A7C59);
const _kBoardLight = Color(0xFFEEEED2);
const _kBoardDark = Color(0xFF769656);

class SpectatorPage extends StatelessWidget {
  final String gameId;

  const SpectatorPage({super.key, required this.gameId});

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
        title: BlocBuilder<SpectatorBloc, SpectatorState>(
          builder: (context, state) {
            if (state is SpectatorWatching) {
              return Text(
                '${state.whiteName} vs ${state.blackName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              );
            }
            return const Text(
              'Spectating',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            );
          },
        ),
        actions: [
          BlocBuilder<SpectatorBloc, SpectatorState>(
            builder: (context, state) {
              if (state is! SpectatorWatching) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar:
                      const Icon(Icons.visibility, size: 14, color: Colors.white),
                  label: Text(
                    '${state.spectatorCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: _kSurface,
                  side: const BorderSide(color: Color(0xFF4A4440)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<SpectatorBloc, SpectatorState>(
        builder: (context, state) {
          if (state is SpectatorConnecting) return _buildConnecting();
          if (state is SpectatorWatching) return _buildWatching(state);
          if (state is SpectatorGameOver) return _buildGameOver(context, state);
          return _buildConnecting();
        },
      ),
    );
  }

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

  Widget _buildWatching(SpectatorWatching state) {
    final isWhiteTurn = state.currentTurn == 'white';

    return SafeArea(
      child: Column(
        children: [
          // Black player (top)
          _SpectatorPlayerRow(
            name: state.blackName,
            isActive: !isWhiteTurn,
            timeMs: state.isTimed ? (state.blackTimeMs ?? 0) : null,
          ),

          // Board — read-only
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: BoardController(
                  state: state.boardState.board,
                  playState: state.boardState.state,
                  moves: state.boardState.moves,
                  onMove: null,
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

          // White player (bottom)
          _SpectatorPlayerRow(
            name: state.whiteName,
            isActive: isWhiteTurn,
            timeMs: state.isTimed ? (state.whiteTimeMs ?? 0) : null,
          ),

          // Spectating label bar
          Container(
            height: 40,
            color: const Color(0xFF1E1B18),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.visibility, size: 14, color: Color(0xFF8B8682)),
                const SizedBox(width: 6),
                Text(
                  'Spectating · ${state.spectatorCount} watching',
                  style: const TextStyle(
                    color: Color(0xFF8B8682),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOver(BuildContext context, SpectatorGameOver state) {
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
                '${state.moveSans.length} moves',
                style:
                    const TextStyle(color: Color(0xFF8B8682), fontSize: 14),
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
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Back to Chess',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Spectator player row (card + clock) ────────────────────────────────────

class _SpectatorPlayerRow extends StatelessWidget {
  final String name;
  final bool isActive;
  final int? timeMs;

  const _SpectatorPlayerRow({
    required this.name,
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
          captured: const [],
        ),
        if (timeMs != null)
          Positioned(
            right: 14,
            child: _SpectatorClock(ms: timeMs!, isActive: isActive),
          ),
      ],
    );
  }
}

// ── Spectator clock ────────────────────────────────────────────────────────

class _SpectatorClock extends StatelessWidget {
  final int ms;
  final bool isActive;

  const _SpectatorClock({required this.ms, required this.isActive});

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
