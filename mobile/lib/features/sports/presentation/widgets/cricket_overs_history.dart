import 'package:flutter/material.dart';
import '../../../../core/l10n/tr.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/cricket_match_state_entity.dart';
import '../bloc/cricket_scoring_cubit.dart';

class CricketOversHistory extends StatelessWidget {
  final CricketMatchStateEntity ms;

  const CricketOversHistory({super.key, required this.ms});

  void _showEditBallSheet(BuildContext context, CricketBallEntity ball) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: context.read<CricketScoringCubit>(),
        child: _EditBallSheet(ball: ball),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ms.oversHistory.isEmpty) return SizedBox.shrink();
    
    return Card(
      margin: EdgeInsets.only(top: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Color(0xFFE3E7F0))),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  trId('overs_log'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.primary),
                ),
                Spacer(),
                Text(
                  '${ms.oversHistory.length} ${ms.oversHistory.length == 1 ? 'over' : 'overs'}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A93A6)),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Rack of over cards, newest on top — each card is one over's stack
            // of deliveries, always visible (no tap-to-expand).
            ...[
              for (var i = ms.oversHistory.length - 1; i >= 0; i--)
                _OverCard(
                  over: ms.oversHistory[i],
                  onBallTap: (ball) => _showEditBallSheet(context, ball),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverCard extends StatelessWidget {
  final CricketOverHistoryEntity over;
  final Function(CricketBallEntity) onBallTap;

  const _OverCard({required this.over, required this.onBallTap});

  @override
  Widget build(BuildContext context) {
    final runsInOver = over.balls.fold(0, (sum, b) => sum + b.runsBatter + b.extrasRuns);
    final wicketsInOver = over.balls.where((b) => b.isWicket).length;
    final bowler = over.balls.isNotEmpty ? over.balls.last.bowlerName : '';

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECF4)),
        boxShadow: [
          BoxShadow(color: AppColors.textPrimary.withOpacity(0.03), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Over-number tile — the spine of the rack.
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(trId('over'),
                    style: TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.5, height: 1)),
                Text('${over.overIndex + 1}',
                    style: TextStyle(color: AppColors.background, fontSize: 17, fontWeight: FontWeight.w900, height: 1.15)),
              ],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: over.balls.map((b) => _BallCircle(ball: b, onTap: () => onBallTap(b))).toList(),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$runsInOver ${runsInOver == 1 ? 'run' : 'runs'}${wicketsInOver > 0 ? ' · $wicketsInOver W' : ''}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0A1128)),
                    ),
                    if (bowler.isNotEmpty)
                      Expanded(
                        child: Text(
                          bowler,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5B6478)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BallCircle extends StatelessWidget {
  final CricketBallEntity ball;
  final VoidCallback onTap;

  const _BallCircle({required this.ball, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isWicket = ball.isWicket;
    final isExtra = ball.extrasType != null && ball.extrasType != 'NONE';
    final isBoundary = !isExtra && !isWicket && (ball.runsBatter == 4 || ball.runsBatter == 6);

    // High-contrast, meaning-coded chips: wicket=red, extra=amber,
    // boundary=brand navy, everything else=light with dark ink.
    late final Color bg;
    late final Color fg;
    late final Color border;
    if (isWicket) {
      bg = const Color(0xFFF43F5E);
      fg = AppColors.background;
      border = const Color(0xFFF43F5E);
    } else if (isExtra) {
      bg = const Color(0xFFF59E0B);
      fg = AppColors.background;
      border = const Color(0xFFF59E0B);
    } else if (isBoundary) {
      bg = AppColors.primary;
      fg = AppColors.background;
      border = AppColors.primary;
    } else {
      bg = const Color(0xFFEFF2FA);
      fg = const Color(0xFF0A1128);
      border = const Color(0xFFD7DCEA);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: 7),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          ball.ballStr,
          maxLines: 1,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: ball.ballStr.length > 2 ? 12 : 15, color: fg),
        ),
      ),
    );
  }
}

class _EditBallSheet extends StatefulWidget {
  final CricketBallEntity ball;

  const _EditBallSheet({required this.ball});

  @override
  State<_EditBallSheet> createState() => _EditBallSheetState();
}

class _EditBallSheetState extends State<_EditBallSheet> {
  late int _runs;
  String? _extrasType;
  late int _extrasRuns;
  late bool _isWicket;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _runs = widget.ball.runsBatter;
    _extrasType = widget.ball.extrasType;
    _extrasRuns = widget.ball.extrasRuns;
    _isWicket = widget.ball.isWicket;
    _notesCtrl.text = widget.ball.notes ?? '';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cubit = context.read<CricketScoringCubit>();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trId('edit_delivery')),
        content: Text(
          'Editing this delivery will automatically recalculate the entire innings. '
          'All subsequent strike rotations, runs, and bowler figures will be adjusted. Are you sure?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(trId('cancel_2'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(trId('recalculate')),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pop(context); // Close sheet
      cubit.editBall(
        ballId: widget.ball.id,
        runsBatter: _runs,
        extrasType: _extrasType,
        extrasRuns: _extrasRuns,
        isWicket: _isWicket,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
    }
  }

  /// High-contrast selectable chip — the stock ChoiceChip left unselected
  /// labels nearly invisible (light grey on white) in this sheet.
  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Color(0xFFEFF2FA),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.primary : Color(0xFFD7DCEA)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.background : Color(0xFF0A1128),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = widget.ball;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trId('edit_ball'),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              '${b.bowlerName} to ${b.strikerName}',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
            ),
            Divider(height: 32),
            Text(trId('batter_runs'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF5B6478))),
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0, 1, 2, 3, 4, 5, 6]
                  .map((r) => _chip('$r', _runs == r, () => setState(() => _runs = r)))
                  .toList(),
            ),
            SizedBox(height: 24),
            Text(trId('extras'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF5B6478))),
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('None', _extrasType == null || _extrasType == 'NONE',
                    () => setState(() { _extrasType = 'NONE'; _extrasRuns = 0; })),
                _chip('Wide', _extrasType == 'WIDE',
                    () => setState(() { _extrasType = 'WIDE'; _extrasRuns = 0; })),
                _chip('No Ball', _extrasType == 'NO_BALL',
                    () => setState(() { _extrasType = 'NO_BALL'; _extrasRuns = 0; })),
                _chip('Bye', _extrasType == 'BYE',
                    () => setState(() { _extrasType = 'BYE'; _extrasRuns = 1; })),
                _chip('Leg Bye', _extrasType == 'LEG_BYE',
                    () => setState(() { _extrasType = 'LEG_BYE'; _extrasRuns = 1; })),
              ],
            ),
            if (_extrasType != null && _extrasType != 'NONE') ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _extrasType == 'WIDE' || _extrasType == 'NO_BALL' ? 'Runs run off it: ' : 'Extra Runs: ',
                  ),
                  SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _extrasRuns,
                    items: [0, 1, 2, 3, 4, 5, 6].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                    onChanged: (v) => setState(() => _extrasRuns = v!),
                  ),
                ],
              ),
            ],
            SizedBox(height: 24),
            SwitchListTile(
              title: Text(trId('wicket_2')),
              contentPadding: EdgeInsets.zero,
              value: _isWicket,
              onChanged: (v) => setState(() => _isWicket = v),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: trId('audit_notes_optional'),
                hintText: trId('reason_for_edit'),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 24),
            Row(
              children: [
                if (widget.ball.hasEditHistory) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<CricketScoringCubit>().undoEditBall(widget.ball.id);
                      },
                      child: Text(trId('undo_last_edit')),
                    ),
                  ),
                  SizedBox(width: 16),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(trId('save_recalculate')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
