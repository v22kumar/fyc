import 'dart:async';
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
import '../widgets/chess_arena_background.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF4A7C59);
const _kGreenBright = Color(0xFF34D17A);
const _kSurface = Color(0xFF15201A);

// ── Board themes ──────────────────────────────────────────────────────────────
class _BoardSkin {
  final String name;
  final Color light;
  final Color dark;
  const _BoardSkin(this.name, this.light, this.dark);
}

const _boardSkins = <_BoardSkin>[
  _BoardSkin('Green', Color(0xFFEEEED2), Color(0xFF769656)),
  _BoardSkin('Wood', Color(0xFFF0D9B5), Color(0xFFB58863)),
  _BoardSkin('Blue', Color(0xFFDEE3E6), Color(0xFF8CA2AD)),
  _BoardSkin('Slate', Color(0xFFCED3DB), Color(0xFF6B7C93)),
];

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
  int _skinIndex = 0;
  double _zoom = 1.0;

  // Ratings
  late int _aiRating;
  int _playerRating = 1500;

  // Clocks (display countdown — visual fidelity to reference design)
  Duration _playerClock = const Duration(minutes: 15);
  Duration _aiClock = const Duration(minutes: 15);
  Timer? _ticker;

  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();

    _aiRating = 800 + widget.skill * 40; // 800 (beginner) → 1600 (expert)

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnim = CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutCubic);

    final storage = sl<LocalStorage>();
    final name = storage.getString('member_name') ?? 'You';
    final storedRating = storage.getString('chess_rating');
    if (storedRating != null) {
      _playerRating = int.tryParse(storedRating) ?? 1500;
    }

    context.read<AiGameBloc>().add(StartAiGame(
          playerName: name,
          depth: widget.depth,
          skill: widget.skill,
          playerIsWhite: widget.playerIsWhite,
        ));

    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _flipCtrl.dispose();
    super.dispose();
  }

  void _tick(Timer t) {
    final s = context.read<AiGameBloc>().state;
    if (s is! AiGameInProgress) return;
    setState(() {
      if (s.isThinking) {
        if (_aiClock > Duration.zero) {
          _aiClock -= const Duration(seconds: 1);
        }
      } else if (s.isPlayerTurn) {
        if (_playerClock > Duration.zero) {
          _playerClock -= const Duration(seconds: 1);
          if (_playerClock <= Duration.zero) {
            // Flag fall — player loses on time
            context.read<AiGameBloc>().add(const ResignToAi());
          }
        }
      }
    });
  }

  void _toggle3D() {
    setState(() => _is3D = !_is3D);
    if (_is3D) {
      _flipCtrl.forward();
    } else {
      _flipCtrl.reverse();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showResult(BuildContext context, AiGameOver state) {
    if (_resultShown) return;
    _resultShown = true;
    _ticker?.cancel();
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

  void _soon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label coming soon'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C09),
      body: ChessArenaBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: BlocConsumer<AiGameBloc, AiGameState>(
                  listener: (context, state) {
                    if (state is AiGameOver) _showResult(context, state);
                    if (state is AiGameIdle) _resultShown = false;
                  },
                  builder: (context, state) {
                    if (state is AiGameInProgress) {
                      return _buildGame(context, state);
                    }
                    if (state is AiGameOver) return _buildOver(context, state);
                    return _buildLoading();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: BlocBuilder<AiGameBloc, AiGameState>(
              builder: (context, state) {
                final name =
                    state is AiGameInProgress ? state.aiName : 'vs Computer';
                return RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'vs ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: name.replaceFirst('Stockfish ', 'Stockfish ('),
                        style: const TextStyle(
                          color: _kGreenBright,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _HeaderIcon(
            icon: Icons.tune_rounded,
            onTap: () => _showBoardSheet(context),
          ),
          _HeaderIcon(
            icon: Icons.flag_outlined,
            onTap: () => _confirmResign(context),
          ),
        ],
      ),
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
            child: CircularProgressIndicator(color: _kGreenBright, strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text('Loading Stockfish…',
              style: TextStyle(color: Color(0xFF8B9A8E), fontSize: 15)),
        ],
      ),
    );
  }

  // ── Game ──────────────────────────────────────────────────────────────────

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

    final skin = _boardSkins[_skinIndex];

    return Column(
      children: [
        // Opponent card
        ChessPlayerCard(
          name: topName,
          rating: topIsAi ? _aiRating : _playerRating,
          isActive: topActive,
          isThinking: state.isThinking && topActive,
          thinkingText: topIsAi ? 'Opponent thinking' : 'thinking',
          avatarColor: topIsAi ? const Color(0xFF2C3A2E) : _kGreen,
          avatarWidget: topIsAi ? const _KnightAvatar() : null,
          captured: topCaptured,
          clock: _fmt(topIsAi ? _aiClock : _playerClock),
          clockLow: (topIsAi ? _aiClock : _playerClock).inSeconds < 30,
        ),

        // Board + right toolbar
        Expanded(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 44, 10),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AnimatedBuilder(
                      animation: _flipAnim,
                      builder: (context, child) {
                        return Transform(
                          alignment: Alignment.center,
                          transform: _build3DMatrix(_flipAnim.value) ..scale(_zoom),
                          child: child,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: _kGreenBright.withOpacity(_is3D ? 0.22 : 0.12),
                              blurRadius: 32,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: BoardController(
                          state: state.boardState.board,
                          playState: state.boardState.state,
                          moves: state.boardState.moves,
                          onMove: (state.isPlayerTurn && !state.isThinking)
                              ? (move) => context
                                  .read<AiGameBloc>()
                                  .add(MakeAiMove(move))
                              : null,
                          pieceSet: PieceSet.merida(),
                          theme: BoardTheme(
                            lightSquare: skin.light,
                            darkSquare: skin.dark,
                            selected: const Color(0xFFFFFFAA),
                            check: const Color(0xAAFF3333),
                            checkmate: const Color(0xAAFF3333),
                            previous: const Color(0xAAF6F669),
                            premove: const Color(0x99AAD4AA),
                          ),
                          animationDuration: const Duration(milliseconds: 200),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Right vertical toolbar
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Center(child: _buildRightToolbar(context)),
              ),
            ],
          ),
        ),

        // 2D/3D pills + Board dropdown
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Row(
            children: [
              _ViewToggle(is3D: _is3D, onChanged: (v) {
                if (v != _is3D) _toggle3D();
              }),
              const Spacer(),
              _BoardDropdown(
                current: skin.name,
                onTap: () => _showBoardSheet(context),
              ),
            ],
          ),
        ),

        // Move bar
        ChessMoveBar(
          moveSans: state.moveSans,
          isThinking: state.isThinking,
          thinkingLabel: state.aiName,
        ),

        // Player card
        ChessPlayerCard(
          name: bottomName,
          rating: bottomIsPlayer ? _playerRating : _aiRating,
          isActive: bottomActive,
          avatarColor: bottomIsPlayer ? _kGreen : const Color(0xFF2C3A2E),
          avatarWidget: bottomIsPlayer ? null : const _KnightAvatar(),
          captured: bottomCaptured,
          clock: _fmt(bottomIsPlayer ? _playerClock : _aiClock),
          clockLow:
              (bottomIsPlayer ? _playerClock : _aiClock).inSeconds < 30,
        ),

        // Action bar
        _ActionBar(
          onTakeBack: (state.moveSans.length >= 2 &&
                  state.isPlayerTurn &&
                  !state.isThinking)
              ? () =>
                  context.read<AiGameBloc>().add(const TakeBackAiMove())
              : null,
          onNewGame: () {
            _resultShown = false;
            context.read<AiGameBloc>().add(const NewAiGame());
            Navigator.pop(context);
          },
          onResign: () => _confirmResign(context),
          onAnalyse: () => _soon('Analysis'),
          onChat: () => _soon('Chat'),
        ),
      ],
    );
  }

  Widget _buildRightToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolBtn(
            label: _is3D ? '3D' : '2D',
            highlighted: _is3D,
            onTap: _toggle3D,
          ),
          _ToolIcon(
            icon: Icons.swap_vert_rounded,
            tooltip: 'Flip board',
            onTap: () => context.read<AiGameBloc>().add(const FlipAiBoard()),
          ),
          _ToolIcon(
            icon: Icons.add_rounded,
            tooltip: 'Zoom in',
            onTap: () => setState(
                () => _zoom = (_zoom + 0.08).clamp(0.85, 1.25)),
          ),
          _ToolIcon(
            icon: Icons.search_rounded,
            tooltip: 'Reset zoom',
            onTap: () => setState(() => _zoom = 1.0),
          ),
          _ToolIcon(
            icon: Icons.bar_chart_rounded,
            tooltip: 'Analysis',
            onTap: () => _soon('Analysis'),
          ),
        ],
      ),
    );
  }

  // ── Game over ───────────────────────────────────────────────────────────────

  Widget _buildOver(BuildContext context, AiGameOver state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.resultLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('${state.moveSans.length} moves played',
                style: const TextStyle(color: Color(0xFF8B9A8E), fontSize: 14)),
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
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('New Game',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Board theme picker sheet ──────────────────────────────────────────────

  void _showBoardSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Board theme',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(_boardSkins.length, (i) {
                final s = _boardSkins[i];
                final selected = i == _skinIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _skinIndex = i);
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? _kGreenBright : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Column(
                            children: [
                              Row(children: [
                                _sq(s.light), _sq(s.dark),
                              ]),
                              Row(children: [
                                _sq(s.dark), _sq(s.light),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(s.name,
                          style: TextStyle(
                              color: selected ? Colors.white : Colors.white60,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sq(Color c) =>
      Container(width: 26, height: 26, color: c);

  // ── Resign dialog ──────────────────────────────────────────────────────────

  void _confirmResign(BuildContext context) {
    final s = context.read<AiGameBloc>().state;
    if (s is! AiGameInProgress) {
      Navigator.pop(context);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resign?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Forfeit this game to ${s.aiName}?',
            style: const TextStyle(color: Color(0xFF8B9A8E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8B9A8E))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AiGameBloc>().add(const ResignToAi());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resign',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── 3D perspective matrix ──────────────────────────────────────────────────

  Matrix4 _build3DMatrix(double t) {
    final m = Matrix4.identity();
    if (t <= 0) return m;

    final tiltX = t * (math.pi / 6.5); // up to ~28° tilt back
    final tiltY = t * (math.pi / 60);

    m.setEntry(3, 2, -0.0022 * t); // perspective
    m.rotateX(tiltX);
    m.rotateY(tiltY);

    final scale = 1.0 - 0.10 * t;
    m.scale(scale, scale, 1.0);
    return m;
  }
}

// ── Knight avatar ─────────────────────────────────────────────────────────────

class _KnightAvatar extends StatelessWidget {
  const _KnightAvatar();

  @override
  Widget build(BuildContext context) {
    return const Text('♞',
        style: TextStyle(
          fontSize: 24,
          color: Colors.white,
          height: 1.1,
        ));
  }
}

// ── Header icon ───────────────────────────────────────────────────────────────

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 22),
      onPressed: onTap,
    );
  }
}

// ── Right-toolbar buttons ─────────────────────────────────────────────────────

class _ToolBtn extends StatelessWidget {
  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.label,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: highlighted ? _kGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted ? _kGreenBright : Colors.white24,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: highlighted ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

// ── 2D/3D view toggle pills ───────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool is3D;
  final ValueChanged<bool> onChanged;

  const _ViewToggle({required this.is3D, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          _pill('2D', !is3D, () => onChanged(false)),
          _pill('3D', is3D, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _pill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _kGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Board dropdown ────────────────────────────────────────────────────────────

class _BoardDropdown extends StatelessWidget {
  final String current;
  final VoidCallback onTap;

  const _BoardDropdown({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Board',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white60, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final VoidCallback? onTakeBack;
  final VoidCallback onNewGame;
  final VoidCallback onResign;
  final VoidCallback onAnalyse;
  final VoidCallback onChat;

  const _ActionBar({
    required this.onTakeBack,
    required this.onNewGame,
    required this.onResign,
    required this.onAnalyse,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.40),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
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
            highlighted: true,
          ),
          _ActionBtn(
            icon: Icons.insights_rounded,
            label: 'Analyse',
            onTap: onAnalyse,
          ),
          _ActionBtn(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat',
            onTap: onChat,
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
  final bool highlighted;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (highlighted) {
      return GestureDetector(
        onTap: disabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _kGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _kGreen.withOpacity(0.5), blurRadius: 12),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    final color =
        disabled ? const Color(0xFF4A5650) : const Color(0xFFBDC7BF);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Result bottom sheet ────────────────────────────────────────────────────────

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
        ? const Color(0xFF8B9A8E)
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
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A463E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(
            state.resultLabel,
            style: TextStyle(
                color: resultColor, fontSize: 18, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text('${state.moveSans.length} moves',
              style: const TextStyle(color: Color(0xFF8B9A8E), fontSize: 14)),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B9A8E),
                    side: const BorderSide(color: Color(0xFF3A463E)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
                        borderRadius: BorderRadius.circular(10)),
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
