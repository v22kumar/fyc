import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/spectator_bloc.dart';
import '../bloc/spectator_state.dart';
import '../widgets/player_info_bar.dart';
import '../widgets/move_history_panel.dart';

class SpectatorPage extends StatelessWidget {
  final String gameId;

  const SpectatorPage({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: BlocBuilder<SpectatorBloc, SpectatorState>(
          builder: (context, state) {
            if (state is SpectatorWatching) {
              return Row(
                children: [
                  Text(
                    '${state.whiteName} vs ${state.blackName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                  avatar: const Icon(Icons.visibility, size: 14, color: Colors.white),
                  label: Text(
                    '${state.spectatorCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: AppColors.darkSurface,
                  side: const BorderSide(color: AppColors.border),
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

  // ── States ─────────────────────────────────────────────────────────────────

  Widget _buildConnecting() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryLight),
          SizedBox(height: 16),
          Text(
            'Connecting…',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildWatching(SpectatorWatching state) {
    final isWhiteTurn = state.currentTurn == 'white';

    return SafeArea(
      child: Column(
        children: [
          // Top player bar — black (opponent from white's perspective)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: PlayerInfoBar(
                    name: state.blackName,
                    captured: const [],
                    isActive: !isWhiteTurn,
                    isTop: true,
                  ),
                ),
                if (state.isTimed)
                  _SpectatorClock(
                    ms: state.blackTimeMs ?? 0,
                    isActive: !isWhiteTurn,
                  ),
              ],
            ),
          ),

          // Board — always read-only (no onMove callback)
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
                    onMove: null,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: MoveHistoryPanel(moveSans: state.moveSans),
          ),

          // Bottom player bar — white
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: PlayerInfoBar(
                    name: state.whiteName,
                    captured: const [],
                    isActive: isWhiteTurn,
                  ),
                ),
                if (state.isTimed)
                  _SpectatorClock(
                    ms: state.whiteTimeMs ?? 0,
                    isActive: isWhiteTurn,
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.resultLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${state.moveSans.length} moves',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  minimumSize: const Size(200, 52),
                ),
                child: const Text(
                  'Back to Chess',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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

// ── Spectator clock widget ────────────────────────────────────────────────────

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
