import 'package:bishop/bishop.dart' as bishop;
import '../../../../core/l10n/tr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';
import '../bloc/online_game_bloc.dart';
import '../bloc/online_game_event.dart';
import '../bloc/online_game_state.dart';
import '../widgets/chess_player_card.dart';
import '../widgets/chess_move_bar.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';

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
        foregroundColor: AppColors.background,
        elevation: 0,
        leadingWidth: 44,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
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
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              );
            }
            return Text(trId('online_game'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
          },
        ),
        actions: [
          BlocBuilder<OnlineGameBloc, OnlineGameState>(
            builder: (context, state) {
              if (state is! OnlineGameInProgress) return SizedBox.shrink();
              return Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.swap_vert_rounded,
                        color: Colors.white54, size: 22),
                    onPressed: () =>
                        context.read<OnlineGameBloc>().add(const FlipOnlineBoard()),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
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
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'draw',
                        child: Text(trId('offer_draw'),
                            style: TextStyle(color: AppColors.background)),
                      ),
                      PopupMenuItem(
                        value: 'resign',
                        child: Text(trId('resign'),
                            style: TextStyle(color: AppColors.danger)),
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
          if (state is OnlineGameConnecting) return _buildConnecting(state.reconnecting);
          if (state is OnlineGameWaiting) return _buildWaiting(state);
          if (state is OnlineGameInProgress) return _buildGame(context, state);
          if (state is OnlineGameOver) return _buildOver(context, state);
          if (state is OnlineGameError) return _buildError(context, state);
          return _buildConnecting(false);
        },
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────

  Widget _buildConnecting(bool reconnecting) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _kGreen),
          SizedBox(height: 16),
          Text(reconnecting ? trId('reconnecting') : trId('connecting'),
              style: TextStyle(color: Color(0xFF8B8682), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, OnlineGameError state) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: Color(0xFF8B8682), size: 48),
              SizedBox(height: 16),
              Text(
                state.message,
                style: TextStyle(
                    color: AppColors.background,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: AppColors.background,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(trId('back_to_chess'),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting(OnlineGameWaiting state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('♛', style: TextStyle(fontSize: 64, color: _kGreen)),
          SizedBox(height: 20),
          CircularProgressIndicator(color: _kGreen),
          SizedBox(height: 16),
          Text(
            trId('waiting_for_opponent'),
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'You play as ${state.myColor}',
            style: TextStyle(color: Color(0xFF8B8682), fontSize: 13),
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
                      onMove: (state.isMyTurn &&
                              !state.moveInFlight &&
                              !state.reconnecting)
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

          // Server froze the board (a move could not be saved). Takes priority
          // over the connection banners: the socket is fine, the game is not.
          if (state.paused)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB3261E)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause_circle_outline,
                        size: 18, color: const Color(0xFFF1746A)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        trId('game_paused_organizer'),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Our-own-connection-lost banner (we are auto-reconnecting)
          if (state.reconnecting)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB45309)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFB45309)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        trId('reconnecting'),
                        style: TextStyle(
                            color: AppColors.background, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Opponent disconnected banner
          if (state.opponentDisconnected && !state.reconnecting)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB45309),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: AppColors.background, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trId('opponent_disconnected_waiting_60s'),
                        style: TextStyle(
                            color: AppColors.background, fontWeight: FontWeight.w600),
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
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4AF37)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trId('opponent_offers_a_draw'),
                      style: TextStyle(
                          color: AppColors.background, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context
                                .read<OnlineGameBloc>()
                                .add(const SendDeclineDraw()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(color: Colors.white24),
                            ),
                            child: Text(trId('decline')),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context
                                .read<OnlineGameBloc>()
                                .add(const SendAcceptDraw()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: AppColors.textPrimary,
                            ),
                            child: Text(trId('accept')),
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
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.resultLabel,
                style: TextStyle(
                    color: AppColors.background,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: AppColors.background,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(trId('back_to_chess'),
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
        title: Text(trId('resign_2'),
            style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700)),
        content: Text(trId('you_will_forfeit_this_game'),
            style: TextStyle(color: Color(0xFF8B8682))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(trId('cancel_2'),
                  style: TextStyle(color: Color(0xFF8B8682)))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<OnlineGameBloc>().add(const SendResign());
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(trId('resign'),
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
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? (isLow ? AppColors.danger.withOpacity(0.8) : _kGreen)
            : const Color(0xFF1E1B18),
        borderRadius: BorderRadius.circular(8),
        border: isActive && isLow
            ? Border.all(color: AppColors.danger.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? AppColors.background : Color(0xFF6B6762),
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
            color: AppColors.danger.withOpacity(0.4),
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
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: c),
            SizedBox(height: 2),
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
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 36),
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
          SizedBox(height: 24),
          Text(
            state.resultLabel,
            style: TextStyle(
              color: _kGreen,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '${state.moveSans.length} moves',
            style: TextStyle(color: Color(0xFF8B8682), fontSize: 14),
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onClose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: AppColors.background,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(trId('back_to_chess'),
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
