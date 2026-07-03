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
        () => tr(en: 'Goals', ta: 'கோல்கள்', hi: 'गोल', ml: 'ഗോളുകൾ'),
        '0',
        () => tr(en: 'Notes — e.g. "2-1, won in extra time"', ta: 'குறிப்பு',
            hi: 'नोट्स', ml: 'കുറിപ്പുകൾ'),
      );
    case 'volleyball':
      return _SportScoring(
        () => tr(en: 'Sets', ta: 'செட்கள்', hi: 'सेट', ml: 'സെറ്റുകൾ'),
        '0',
        () => tr(en: 'Notes — e.g. "25-20, 25-18, 25-22"', ta: 'குறிப்பு',
            hi: 'नोट्स', ml: 'കുറിപ്പുകൾ'),
      );
    case 'kabaddi':
      return _SportScoring(
        () => tr(en: 'Points', ta: 'புள்ளிகள்', hi: 'अंक', ml: 'പോയിന്റുകൾ'),
        '0',
        () => tr(en: 'Notes — e.g. "42-38, won by 4"', ta: 'குறிப்பு',
            hi: 'नोट्स', ml: 'കുറിപ്പുകൾ'),
      );
    case 'carrom':
      return _SportScoring(
        () => tr(en: 'Points', ta: 'புள்ளிகள்', hi: 'अंक', ml: 'പോയിന്റുകൾ'),
        '0',
        () => tr(en: 'Notes — e.g. "Best of 3, 2-1"', ta: 'குறிப்பு',
            hi: 'नोट्स', ml: 'കുറിപ്പുകൾ'),
      );
    default:
      return _SportScoring(
        () => tr(en: 'Score', ta: 'மதிப்பெண்', hi: 'स्कोर', ml: 'സ്കോർ'),
        '0',
        () => tr(en: 'Notes (optional)', ta: 'குறிப்பு (விருப்பம்)',
            hi: 'नोट्स (वैकल्पिक)', ml: 'കുറിപ്പുകൾ (ഓപ്ഷണൽ)'),
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
              ? tr(en: 'Result saved', ta: 'முடிவு சேமிக்கப்பட்டது',
                  hi: 'परिणाम सहेजा गया', ml: 'ഫലം സേവ് ചെയ്തു')
              : tr(en: 'Score submitted — pending admin approval',
                  ta: 'மதிப்பெண் சமர்ப்பிக்கப்பட்டது — நிர்வாக ஒப்புதலுக்காக',
                  hi: 'स्कोर सबमिट — एडमिन अनुमोदन बाकी',
                  ml: 'സ്കോർ സമർപ്പിച്ചു — അഡ്മിൻ അംഗീകാരം ബാക്കി')),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          SnackBar(content: Text(tr(en: 'Could not submit score', ta: 'சமர்ப்பிக்க முடியவில்லை',
              hi: 'सबमिट नहीं हो सका', ml: 'സമർപ്പിക്കാനായില്ല')), backgroundColor: AppColors.accent),
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
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '${tr(en: 'Enter Score', ta: 'மதிப்பெண்ணை பதிவு செய்', hi: 'स्कोर दर्ज करें', ml: 'സ്കോർ നൽകുക')} · ${scoring.unitLabel()}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.cText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.isManager
                ? tr(en: 'This result is saved to the standings right away.',
                    ta: 'இந்த முடிவு உடனடியாக புள்ளிப்பட்டியலில் சேமிக்கப்படும்.',
                    hi: 'यह परिणाम तुरंत अंक तालिका में सहेजा जाएगा।',
                    ml: 'ഈ ഫലം ഉടനെ പോയിന്റ് പട്ടികയിൽ സേവ് ചെയ്യും.')
                : tr(en: 'Your entry will be sent to an admin for approval.',
                    ta: 'உங்கள் பதிவு நிர்வாக ஒப்புதலுக்கு அனுப்பப்படும்.',
                    hi: 'आपकी प्रविष्टि एडमिन अनुमोदन के लिए भेजी जाएगी।',
                    ml: 'നിങ്ങളുടെ എൻട്രി അഡ്മിൻ അംഗീകാരത്തിനായി അയയ്ക്കും.'),
            style: TextStyle(fontSize: 11.5, color: context.cTextSecondary),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(child: _ScoreField(label: teamA, controller: _scoreACtrl, hint: scoring.hint)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('vs', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
              ),
              Expanded(child: _ScoreField(label: teamB, controller: _scoreBCtrl, hint: scoring.hint)),
            ],
          ),
          const SizedBox(height: 18),

          Text(tr(en: 'Winner', ta: 'வெற்றியாளர்', hi: 'विजेता', ml: 'വിജയി'),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.cText)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _WinnerChip(label: teamA, selected: _winnerId == widget.fixture.teamAId,
                  onTap: () => setState(() => _winnerId = widget.fixture.teamAId)),
              _WinnerChip(label: teamB, selected: _winnerId == widget.fixture.teamBId,
                  onTap: () => setState(() => _winnerId = widget.fixture.teamBId)),
              _WinnerChip(label: tr(en: 'Draw / TBD', ta: 'சமன் / பின்னர்',
                  hi: 'ड्रॉ / बाद में', ml: 'സമനില / പിന്നീട്'), selected: _winnerId == null,
                  onTap: () => setState(() => _winnerId = null)),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: scoring.notesHint(),
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
                  : Text(
                      widget.isManager
                          ? tr(en: 'Save result', ta: 'முடிவைச் சேமி', hi: 'परिणाम सहेजें', ml: 'ഫലം സേവ് ചെയ്യുക')
                          : tr(en: 'Submit for approval', ta: 'ஒப்புதலுக்கு சமர்ப்பி', hi: 'अनुमोदन हेतु सबमिट', ml: 'അംഗീകാരത്തിന് സമർപ്പിക്കുക'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: hint,
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
