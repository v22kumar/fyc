import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    if (ms.oversHistory.isEmpty) return const SizedBox.shrink();
    
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Previous Overs',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Scroll to top or to scoring pad? Not implemented here since the pad is sticky at the bottom.
                  },
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  label: const Text('Live'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ms.oversHistory.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                // Show latest first
                final over = ms.oversHistory.reversed.toList()[index];
                return _OverTimeline(
                  over: over,
                  onBallTap: (ball) => _showEditBallSheet(context, ball),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OverTimeline extends StatelessWidget {
  final CricketOverHistoryEntity over;
  final Function(CricketBallEntity) onBallTap;

  const _OverTimeline({required this.over, required this.onBallTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runsInOver = over.balls.fold(0, (sum, b) => sum + b.runsBatter + b.extrasRuns);
    final wicketsInOver = over.balls.where((b) => b.isWicket).length;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true, // or false depending on preference
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Over ${over.overIndex + 1}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$runsInOver runs${wicketsInOver > 0 ? ', $wicketsInOver W' : ''}',
              style: theme.textTheme.bodyMedium,
            ),
            if (over.balls.isNotEmpty) ...[
              const Spacer(),
              Text(
                over.balls.last.bowlerName,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
              ),
            ]
          ],
        ),
        children: [
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: over.balls.map((b) => _BallCircle(ball: b, onTap: () => onBallTap(b))).toList(),
            ),
          ),
          const SizedBox(height: 8),
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
    final theme = Theme.of(context);
    final isWicket = ball.isWicket;
    final isExtra = ball.extrasType != null && ball.extrasType != 'NONE';
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isWicket ? theme.colorScheme.error : (isExtra ? theme.colorScheme.tertiary : theme.colorScheme.surface),
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          ball.ballStr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isWicket ? theme.colorScheme.onError : (isExtra ? theme.colorScheme.onTertiary : theme.colorScheme.onSurface),
          ),
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
        title: const Text('Edit Delivery?'),
        content: const Text(
          'Editing this delivery will automatically recalculate the entire innings. '
          'All subsequent strike rotations, runs, and bowler figures will be adjusted. Are you sure?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Recalculate'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = widget.ball;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  'Edit Ball',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${b.bowlerName} to ${b.strikerName}',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
            ),
            const Divider(height: 32),
            Text('Batter Runs', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [0, 1, 2, 3, 4, 5, 6].map((r) => ChoiceChip(
                label: Text('$r'),
                selected: _runs == r,
                onSelected: (_) => setState(() => _runs = r),
              )).toList(),
            ),
            const SizedBox(height: 24),
            Text('Extras', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: _extrasType == null || _extrasType == 'NONE',
                  onSelected: (_) => setState(() {
                    _extrasType = 'NONE';
                    _extrasRuns = 0;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Wide'),
                  selected: _extrasType == 'WIDE',
                  onSelected: (_) => setState(() {
                    _extrasType = 'WIDE';
                    _extrasRuns = 1;
                  }),
                ),
                ChoiceChip(
                  label: const Text('No Ball'),
                  selected: _extrasType == 'NO_BALL',
                  onSelected: (_) => setState(() {
                    _extrasType = 'NO_BALL';
                    _extrasRuns = 1;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Bye'),
                  selected: _extrasType == 'BYE',
                  onSelected: (_) => setState(() {
                    _extrasType = 'BYE';
                    _extrasRuns = 1;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Leg Bye'),
                  selected: _extrasType == 'LEG_BYE',
                  onSelected: (_) => setState(() {
                    _extrasType = 'LEG_BYE';
                    _extrasRuns = 1;
                  }),
                ),
              ],
            ),
            if (_extrasType != null && _extrasType != 'NONE') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Extra Runs: '),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _extrasRuns,
                    items: [1, 2, 3, 4, 5, 6].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                    onChanged: (v) => setState(() => _extrasRuns = v!),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Wicket?'),
              contentPadding: EdgeInsets.zero,
              value: _isWicket,
              onChanged: (v) => setState(() => _isWicket = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Audit Notes (optional)',
                hintText: 'Reason for edit',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.ball.hasEditHistory) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<CricketScoringCubit>().undoEditBall(widget.ball.id);
                      },
                      child: const Text('Undo Last Edit'),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save & Recalculate'),
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
