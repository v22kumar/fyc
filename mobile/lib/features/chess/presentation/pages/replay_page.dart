import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/chess_remote_datasource.dart';
import '../../data/models/chess_game_model.dart';

class ReplayPage extends StatefulWidget {
  final String gameId;

  const ReplayPage({super.key, required this.gameId});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  ChessGameDetailModel? _game;
  String? _error;

  // Replay state
  final _engine = bishop.Game(variant: bishop.Variant.standard());
  final _history = <bishop.Game>[]; // snapshots after each half-move
  int _ply = 0; // 0 = initial position, 1 = after move 1, etc.
  late SquaresState _boardState;

  @override
  void initState() {
    super.initState();
    _boardState = _engine.squaresState(Squares.white);
    _loadGame();
  }

  Future<void> _loadGame() async {
    try {
      final game = await sl<ChessRemoteDataSource>().getGame(widget.gameId);
      if (!mounted) return;
      // Pre-apply all moves and store snapshots
      _buildHistory(game.moves);
      setState(() => _game = game);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _buildHistory(List<ChessMoveModel> moves) {
    _history.clear();
    final engine = bishop.Game(variant: bishop.Variant.standard());
    for (final m in moves) {
      final legalMoves = engine.generateLegalMoves();
      for (final lm in legalMoves) {
        if (engine.toAlgebraic(lm) == m.uci) {
          engine.makeMove(lm);
          break;
        }
      }
      // Store a snapshot of the FEN at each point
      _history.add(bishop.Game(variant: bishop.Variant.standard())
        ..loadFen(engine.fen));
    }
    _ply = 0;
    _boardState = bishop.Game(variant: bishop.Variant.standard())
        .squaresState(Squares.white);
  }

  void _goTo(int ply) {
    if (ply < 0 || ply > _history.length) return;
    final orientation = Squares.white;
    if (ply == 0) {
      setState(() {
        _ply = 0;
        _boardState =
            bishop.Game(variant: bishop.Variant.standard()).squaresState(orientation);
      });
    } else {
      setState(() {
        _ply = ply;
        _boardState = _history[ply - 1].squaresState(orientation);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _game != null
              ? '${_game!.whiteName ?? "White"} vs ${_game!.blackName ?? "Black"}'
              : 'Game Replay',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_game != null)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white70),
              tooltip: 'Share PGN',
              onPressed: () => _sharePgn(_game!),
            ),
        ],
      ),
      body: _error != null
          ? _buildError()
          : _game == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryLight))
              : _buildReplay(_game!),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.warning, size: 48),
          const SizedBox(height: 12),
          const Text('Could not load game',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text(_error ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildReplay(ChessGameDetailModel game) {
    final white = game.whiteName ?? 'White';
    final black = game.blackName ?? 'Black';
    final total = game.moves.length;
    final canBack = _ply > 0;
    final canForward = _ply < total;

    return SafeArea(
      child: Column(
        children: [
          // Black player (top)
          _PlayerBar(name: black, isTop: true),

          // Board (read-only)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: BoardController(
                    state: _boardState.board,
                    playState: _boardState.state,
                    moves: _boardState.moves,
                    onMove: null, // read-only
                    pieceSet: PieceSet.merida(),
                    theme: BoardTheme(
                      lightSquare: const Color(0xFFF0D9B5),
                      darkSquare: const Color(0xFFB58863),
                      selected: Colors.transparent,
                      check: Colors.red.withOpacity(0.6),
                      checkmate: Colors.red.withOpacity(0.6),
                      previous: AppColors.gold.withOpacity(0.5),
                      premove: Colors.transparent,
                    ),
                    animationDuration: const Duration(milliseconds: 150),
                  ),
                ),
              ),
            ),
          ),

          // Move history scrollable with highlighted ply
          _ReplayMoveList(
            moves: game.moves,
            currentPly: _ply,
            onTap: _goTo,
          ),

          // White player (bottom)
          _PlayerBar(name: white, isTop: false),

          // Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ControlBtn(
                  icon: Icons.skip_previous_rounded,
                  onPressed: canBack ? () => _goTo(0) : null,
                ),
                const SizedBox(width: 8),
                _ControlBtn(
                  icon: Icons.chevron_left_rounded,
                  onPressed: canBack ? () => _goTo(_ply - 1) : null,
                  large: true,
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(_ply / 2).ceil()} / ${(total / 2).ceil()}',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                _ControlBtn(
                  icon: Icons.chevron_right_rounded,
                  onPressed: canForward ? () => _goTo(_ply + 1) : null,
                  large: true,
                ),
                const SizedBox(width: 8),
                _ControlBtn(
                  icon: Icons.skip_next_rounded,
                  onPressed: canForward ? () => _goTo(total) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sharePgn(ChessGameDetailModel game) {
    Share.share(game.pgn, subject: 'FYC Chess Game');
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _PlayerBar extends StatelessWidget {
  final String name;
  final bool isTop;
  const _PlayerBar({required this.name, required this.isTop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, isTop ? 8 : 4, 12, isTop ? 4 : 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const Spacer(),
          Text(
            isTop ? '♚ Black' : '♔ White',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ReplayMoveList extends StatefulWidget {
  final List<ChessMoveModel> moves;
  final int currentPly;
  final void Function(int ply) onTap;
  const _ReplayMoveList(
      {required this.moves,
      required this.currentPly,
      required this.onTap});

  @override
  State<_ReplayMoveList> createState() => _ReplayMoveListState();
}

class _ReplayMoveListState extends State<_ReplayMoveList> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(_ReplayMoveList old) {
    super.didUpdateWidget(old);
    if (old.currentPly != widget.currentPly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        // Scroll to roughly the right position
        final targetOffset = (widget.currentPly / 2 * 60.0).clamp(
            0.0, _scroll.position.maxScrollExtent);
        _scroll.animateTo(targetOffset,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pairs = <(int, String, String?)>[];
    for (var i = 0; i < widget.moves.length; i += 2) {
      final white = widget.moves[i].san;
      final black = i + 1 < widget.moves.length ? widget.moves[i + 1].san : null;
      pairs.add((i ~/ 2 + 1, white, black));
    }

    return Container(
      height: 52,
      color: AppColors.darkSurface,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: pairs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final (moveNum, white, black) = pairs[i];
          final whitePly = i * 2 + 1;
          final blackPly = i * 2 + 2;
          return Row(
            children: [
              Text('$moveNum.',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 4),
              _MovePill(
                san: white,
                active: widget.currentPly == whitePly,
                onTap: () => widget.onTap(whitePly),
              ),
              if (black != null) ...[
                const SizedBox(width: 4),
                _MovePill(
                  san: black,
                  active: widget.currentPly == blackPly,
                  onTap: () => widget.onTap(blackPly),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MovePill extends StatelessWidget {
  final String san;
  final bool active;
  final VoidCallback onTap;
  const _MovePill(
      {required this.san, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          san,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool large;
  const _ControlBtn({required this.icon, this.onPressed, this.large = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon,
          size: large ? 36 : 28,
          color: onPressed != null ? Colors.white : Colors.white24),
      onPressed: onPressed,
      splashRadius: 24,
    );
  }
}
