import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/fixture_entity.dart';

/// Bottom sheet for a CLUB_MEMBER to submit a live/final score.
/// The submission is created as PENDING and must be approved by an admin.
/// Returns true via Navigator.pop when a score was submitted successfully.
class LiveScoreEntrySheet extends StatefulWidget {
  final FixtureEntity fixture;
  const LiveScoreEntrySheet({super.key, required this.fixture});

  @override
  State<LiveScoreEntrySheet> createState() => _LiveScoreEntrySheetState();
}

class _LiveScoreEntrySheetState extends State<LiveScoreEntrySheet> {
  final _scoreACtrl = TextEditingController();
  final _scoreBCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _winnerId; // null = no winner yet / draw
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _scoreACtrl.text = widget.fixture.teamAScore ?? '';
    _scoreBCtrl.text = widget.fixture.teamBScore ?? '';
    _winnerId = widget.fixture.winnerId;
  }

  @override
  void dispose() {
    _scoreACtrl.dispose();
    _scoreBCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    // Capture the messenger before popping so we don't use a dead context.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sl<ApiClient>().dio.post(
        ApiConstants.sportsFixtureLiveEntry(widget.fixture.id),
        data: {
          'team_a_score': _scoreACtrl.text.trim().isEmpty ? null : _scoreACtrl.text.trim(),
          'team_b_score': _scoreBCtrl.text.trim().isEmpty ? null : _scoreBCtrl.text.trim(),
          'winner_id': _winnerId,
          'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Score submitted — pending admin approval'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not submit score'), backgroundColor: AppColors.accent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamA = widget.fixture.teamAName ?? 'Team A';
    final teamB = widget.fixture.teamBName ?? 'Team B';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Enter Live Score',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.cText)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Your entry will be sent to an admin for approval.',
              style: TextStyle(fontSize: 11.5, color: context.cTextSecondary)),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(child: _ScoreField(label: teamA, controller: _scoreACtrl)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('vs', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
              ),
              Expanded(child: _ScoreField(label: teamB, controller: _scoreBCtrl)),
            ],
          ),
          const SizedBox(height: 18),

          Text('Winner', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.cText)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _WinnerChip(label: teamA, selected: _winnerId == widget.fixture.teamAId,
                  onTap: () => setState(() => _winnerId = widget.fixture.teamAId)),
              _WinnerChip(label: teamB, selected: _winnerId == widget.fixture.teamBId,
                  onTap: () => setState(() => _winnerId = widget.fixture.teamBId)),
              _WinnerChip(label: 'Draw / TBD', selected: _winnerId == null,
                  onTap: () => setState(() => _winnerId = null)),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Notes (optional) — e.g. "Won by 20 runs"',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Submit for Approval',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _ScoreField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.cText),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ],
    );
  }
}

class _WinnerChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _WinnerChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : context.cSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : context.cBorder, width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : context.cText,
            )),
      ),
    );
  }
}
