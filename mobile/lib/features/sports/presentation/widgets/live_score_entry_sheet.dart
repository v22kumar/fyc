import 'package:flutter/material.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/fixture_entity.dart';

/// Bottom sheet to record a live/final score for a non-cricket fixture.
///
/// A manager's entry is applied immediately; a club member's stays PENDING
/// until an admin approves it. The labels adapt to the sport (goals / sets /
/// points …) so each game reads in its own terms.
/// Returns true via Navigator.pop when a score was submitted successfully.
class LiveScoreEntrySheet extends StatefulWidget {
  final FixtureEntity fixture;
  final String sport;
  final bool isManager;
  const LiveScoreEntrySheet({
    super.key,
    required this.fixture,
    this.sport = 'other',
    this.isManager = false,
  });

  @override
  State<LiveScoreEntrySheet> createState() => _LiveScoreEntrySheetState();
}

/// Per-sport scoring vocabulary so the entry sheet reads in each game's terms.
class _SportScoring {
  final String Function() unitLabel; // e.g. "Goals", "Sets", "Points"
  final String hint; // score field hint
  final String Function() notesHint;
  const _SportScoring(this.unitLabel, this.hint, this.notesHint);
}

_SportScoring _scoringFor(String sport) {
  switch (sport.toLowerCase()) {
    case 'football':
      return _SportScoring(
        () => trId('goals'),
        '0',
        () => trId('notes_e_g_2_1_won_in_extra_time'),
      );
    case 'volleyball':
      return _SportScoring(
        () => trId('sets'),
        '0',
        () => trId('notes_e_g_25_20_25_18_25_22'),
      );
    case 'kabaddi':
      return _SportScoring(
        () => trId('points'),
        '0',
        () => trId('notes_e_g_42_38_won_by_4'),
      );
    case 'carrom':
      return _SportScoring(
        () => trId('points'),
        '0',
        () => trId('notes_e_g_best_of_3_2_1'),
      );
    default:
      return _SportScoring(
        () => trId('score'),
        '0',
        () => trId('notes_optional'),
      );
  }
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
        SnackBar(
          content: Text(widget.isManager
              ? trId('result_saved')
              : trId('score_submitted_pending_admin_approval')),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          SnackBar(content: Text(trId('could_not_submit_score')), backgroundColor: AppColors.accent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamA = widget.fixture.teamAName ?? 'Team A';
    final teamB = widget.fixture.teamBName ?? 'Team B';
    final scoring = _scoringFor(widget.sport);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(4)))),
          SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                '${trId('enter_score')} · ${scoring.unitLabel()}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.cText),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            widget.isManager
                ? trId('this_result_is_saved_to_the_standings_ri')
                : trId('your_entry_will_be_sent_to_an_admin_for'),
            style: TextStyle(fontSize: 11.5, color: context.cTextSecondary),
          ),
          SizedBox(height: 18),

          Row(
            children: [
              Expanded(child: _ScoreField(label: teamA, controller: _scoreACtrl, hint: scoring.hint)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(trId('vs_2'), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ),
              Expanded(child: _ScoreField(label: teamB, controller: _scoreBCtrl, hint: scoring.hint)),
            ],
          ),
          SizedBox(height: 18),

          Text(trId('winner'),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.cText)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _WinnerChip(label: teamA, selected: _winnerId == widget.fixture.teamAId,
                  onTap: () => setState(() => _winnerId = widget.fixture.teamAId)),
              _WinnerChip(label: teamB, selected: _winnerId == widget.fixture.teamBId,
                  onTap: () => setState(() => _winnerId = widget.fixture.teamBId)),
              _WinnerChip(label: trId('draw_tbd'), selected: _winnerId == null,
                  onTap: () => setState(() => _winnerId = null)),
            ],
          ),
          SizedBox(height: 16),

          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: scoring.notesHint(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          SizedBox(height: 20),

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
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2.5))
                  : Text(
                      widget.isManager
                          ? trId('save_result')
                          : trId('submit_for_approval'),
                      style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700, fontSize: 15)),
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
  final String hint;
  const _ScoreField({required this.label, required this.controller, this.hint = '0'});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.cText),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
