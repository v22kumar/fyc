import 'package:flutter/material.dart';
import '../../../../core/l10n/tr.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/tournament_entity.dart';

// Per-sport match configuration options
const _matchConfigBySport = <String, List<String>>{
  'cricket': ['5 Overs', '10 Overs', '20 Overs', '25 Overs'],
  'football': ['2 × 30 min', '2 × 45 min'],
  'kabaddi': ['2 × 20 min', '2 × 15 min'],
  'volleyball': ['Best of 3 sets', 'Best of 5 sets'],
  'carrom': ['Best of 3', 'Best of 5'],
  'chess': ['Blitz', 'Rapid', 'Classical'],
  'other': [],
};

const _matchConfigLabel = <String, String>{
  'cricket': 'Match Type (Overs)',
  'football': 'Match Duration',
  'kabaddi': 'Match Duration',
  'volleyball': 'Match Format',
  'carrom': 'Match Format',
  'chess': 'Time Control',
  'other': 'Match Format',
};

class _SportOpt {
  final String value, emoji, labelEn;
  const _SportOpt(this.value, this.emoji, this.labelEn);
}

const _sports = <_SportOpt>[
  _SportOpt('cricket', '🏏', 'Cricket'),
  _SportOpt('kabaddi', '🤼', 'Kabaddi'),
  _SportOpt('volleyball', '🏐', 'Volleyball'),
  _SportOpt('football', '⚽', 'Football'),
  _SportOpt('carrom', '🎯', 'Carrom'),
  _SportOpt('chess', '♟', 'Chess'),
  _SportOpt('other', '🏅', 'Other'),
];

const _formats = ['LEAGUE', 'ROUND_ROBIN', 'DOUBLE_ROUND', 'KNOCKOUT', 'CUSTOM'];
/// Built per call, not const: the labels come from the registry, and a const
/// map would bake in whichever language happened to load first.
Map<String, String> get _formatLabels => {
      'LEAGUE': trId('league'),
      'ROUND_ROBIN': trId('round_robin'),
      'DOUBLE_ROUND': trId('double_round'),
      'KNOCKOUT': trId('knockout'),
      'CUSTOM': trId('custom'),
    };

class CreateTournamentScreen extends StatefulWidget {
  final TournamentEntity? tournament;
  const CreateTournamentScreen({super.key, this.tournament});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _nameCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _prizeCtrl = TextEditingController();
  final _customTeamsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _sport = 'cricket';
  int? _numTeams = 8;
  bool _customTeams = false;
  String _format = 'LEAGUE';
  String? _matchConfig = '20 Overs';
  String _registration = 'MANUAL_APPROVAL';
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _regCloseDate; // registration deadline — required
  bool _showPoints = true;
  bool _showLive = true;
  bool _showPrize = false;
  bool _villageWides = false;
  bool _submitting = false;
  bool _showAdvanced = false;

  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    if (widget.tournament != null) {
      final t = widget.tournament!;
      _nameCtrl.text = t.nameEn;
      _venueCtrl.text = t.venue ?? '';
      _prizeCtrl.text = t.prizeDetails ?? '';
      _descCtrl.text = t.descriptionEn ?? '';
      _sport = t.sport;
      _numTeams = t.numTeams;
      _format = t.format;
      _matchConfig = t.matchConfig;
      _registration = t.registrationMode;
      _startDate = t.startDate;
      _endDate = t.endDate;
      _regCloseDate = t.registrationCloseDate;
      _showPoints = t.showPointsTable;
      _showLive = t.showLiveScores;
      _villageWides = t.villageWides;
      _showPrize = t.showPrizeDetails;
    } else {
      _loadDraft();
      _nameCtrl.addListener(_saveDraft);
      _venueCtrl.addListener(_saveDraft);
      _prizeCtrl.addListener(_saveDraft);
      _customTeamsCtrl.addListener(_saveDraft);
      _descCtrl.addListener(_saveDraft);
    }
  }

  void _loadDraft() {
    final storage = sl<LocalStorage>();
    _nameCtrl.text = storage.getDraft('tournament_draft_name') ?? '';
    _venueCtrl.text = storage.getDraft('tournament_draft_venue') ?? '';
    _prizeCtrl.text = storage.getDraft('tournament_draft_prize') ?? '';
    _customTeamsCtrl.text = storage.getDraft('tournament_draft_custom_teams') ?? '';
    _descCtrl.text = storage.getDraft('tournament_draft_desc') ?? '';
  }

  void _saveDraft() {
    final storage = sl<LocalStorage>();
    storage.saveDraft('tournament_draft_name', _nameCtrl.text);
    storage.saveDraft('tournament_draft_venue', _venueCtrl.text);
    storage.saveDraft('tournament_draft_prize', _prizeCtrl.text);
    storage.saveDraft('tournament_draft_custom_teams', _customTeamsCtrl.text);
    storage.saveDraft('tournament_draft_desc', _descCtrl.text);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _venueCtrl.dispose();
    _prizeCtrl.dispose();
    _customTeamsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onSportChanged(String s) {
    setState(() {
      _sport = s;
      final opts = _matchConfigBySport[s] ?? [];
      _matchConfig = opts.isNotEmpty ? opts.first : null;
    });
  }

  int? get _effectiveNumTeams {
    if (_customTeams) return int.tryParse(_customTeamsCtrl.text.trim());
    return _numTeams;
  }

  Future<void> _pickRegClose() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _regCloseDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _regCloseDate = picked);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Please enter a tournament name');
      return;
    }
    // Registration close date is required only when CREATING a tournament. When
    // editing an existing one (its registration may already be over / never had
    // a date), don't block the save on it.
    if (widget.tournament == null && _regCloseDate == null) {
      _snack('Please set the registration close date');
      return;
    }
    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'name_en': name,
        'name_ta': name,
        'sport': _sport,
        'year': (_startDate ?? DateTime.now()).year,
        'format': _format,
        'num_teams': _effectiveNumTeams,
        'match_config': _matchConfig,
        'registration_mode': _registration,
        'venue': _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
        'show_points_table': _showPoints,
        'show_live_scores': _showLive,
        'show_prize_details': _showPrize,
        'village_wides': _villageWides,
        'prize_details': _showPrize && _prizeCtrl.text.trim().isNotEmpty ? _prizeCtrl.text.trim() : null,
        'description_en': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'description_ta': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        if (_startDate != null) 'start_date': _startDate!.toUtc().toIso8601String(),
        if (_endDate != null) 'end_date': _endDate!.toUtc().toIso8601String(),
        // Registration stays open through the whole chosen day (end-of-day).
        // Only sent when set (an edited, registration-closed tournament may
        // have none) so it never force-unwraps null.
        if (_regCloseDate != null)
          'registration_close_date': DateTime(
            _regCloseDate!.year, _regCloseDate!.month, _regCloseDate!.day, 23, 59, 59,
          ).toUtc().toIso8601String(),
      };
      if (widget.tournament != null) {
        await sl<ApiClient>().dio.put(
          '${ApiConstants.sportsTournaments}/${widget.tournament!.id}',
          data: body,
        );
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        final res = await sl<ApiClient>().dio.post(ApiConstants.sportsTournaments, data: body);
        final id = res.data['id'] as String?;
        if (!mounted) return;
        final storage = sl<LocalStorage>();
        storage.clearDraft('tournament_draft_name');
        storage.clearDraft('tournament_draft_venue');
        storage.clearDraft('tournament_draft_prize');
        storage.clearDraft('tournament_draft_custom_teams');
        storage.clearDraft('tournament_draft_desc');
        _showCreatedSheet(id);
      }
    } catch (e) {
      _snack(
        widget.tournament != null
            ? 'We couldn\'t update the tournament right now. Please check your connection and try again.'
            : 'We couldn\'t create the tournament right now. Please check your connection and try again.',
        onRetry: _submit,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.accent,
        action: onRetry != null
            ? SnackBarAction(
                label: trId('retry'),
                textColor: AppColors.background,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  void _showCreatedSheet(String? id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: context.cBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(4)))),
            SizedBox(height: 22),
            Container(
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), shape: BoxShape.circle),
              child: Text('🏆', style: TextStyle(fontSize: 40)),
            ),
            SizedBox(height: 16),
            Text(trId('tournament_created'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cText)),
            SizedBox(height: 8),
            Text(
              trId('now_register_teams_then_tap_generate_fix'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: context.cTextSecondary, height: 1.5),
            ),
            SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (id != null) {
                    context.go('/sports/tournament', extra: {'tournamentId': id});
                  } else {
                    context.pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(trId('manage_tournament'),
                    style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sportOpt = _sports.firstWhere((s) => s.value == _sport, orElse: () => _sports.last);
    final configOpts = _matchConfigBySport[_sport] ?? [];

    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cSurface,
        elevation: 0,
        title: Text(widget.tournament != null ? 'Edit Tournament' : 'Create Tournament',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.cText)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Sport selector
          _Label('Select Sport'),
          SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sports.length,
              separatorBuilder: (_, __) => SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _sports[i];
                final sel = s.value == _sport;
                return ChoiceChip(
                  selected: sel,
                  onSelected: (_) => _onSportChanged(s.value),
                  label: Text('${s.emoji} ${s.labelEn}'),
                  labelStyle: TextStyle(
                      color: sel ? AppColors.background : context.cText, fontWeight: FontWeight.w600, fontSize: 12),
                  selectedColor: AppColors.primary,
                  backgroundColor: context.cSurface,
                );
              },
            ),
          ),
          SizedBox(height: 18),

          // Tournament name
          _Label('Tournament Name'),
          SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: _dec(context, 'e.g. FYC Summer ${DateTime.now().year}', Icons.emoji_events_outlined),
          ),
          SizedBox(height: 18),

          // Registration deadline (required — drives the register→close→fixtures flow)
          _Label('Registration Closes On *'),
          SizedBox(height: 8),
          _DateField(
            label: trId('last_day_to_register'),
            date: _regCloseDate,
            onTap: _pickRegClose,
          ),
          SizedBox(height: 6),
          Text(
            trId('teams_can_register_until_this_date_fixtu'),
            style: TextStyle(fontSize: 11.5, color: context.cTextSecondary),
          ),
          SizedBox(height: 18),

          // Dates
          _Label('Tournament Dates'),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _DateField(label: trId('start_date'), date: _startDate, onTap: () => _pickDate(isStart: true))),
              SizedBox(width: 10),
              Expanded(child: _DateField(label: trId('end_date'), date: _endDate, onTap: () => _pickDate(isStart: false))),
            ],
          ),
          SizedBox(height: 18),

          // Advanced settings toggle
          GestureDetector(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showAdvanced ? 'Hide Advanced Settings' : 'Show Advanced Settings',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                Icon(
                  _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          SizedBox(height: 18),

          if (_showAdvanced) ...[
            // Number of teams
            _Label('Number of Teams'),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final n in [4, 6, 8, 16])
                  _PickChip(
                    label: '$n',
                    selected: !_customTeams && _numTeams == n,
                    onTap: () => setState(() { _customTeams = false; _numTeams = n; }),
                  ),
                _PickChip(
                  label: trId('custom'),
                  selected: _customTeams,
                  onTap: () => setState(() => _customTeams = true),
                ),
              ],
            ),
            if (_customTeams) ...[
              SizedBox(height: 10),
              TextField(
                controller: _customTeamsCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: _dec(context, 'Enter number of teams', Icons.groups_outlined),
              ),
            ],
            SizedBox(height: 18),

            // Format
            _Label('Format'),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _formats.map((f) => _PickChip(
                label: _formatLabels[f]!,
                selected: _format == f,
                onTap: () => setState(() => _format = f),
              )).toList(),
            ),
            SizedBox(height: 18),

            // Match config (sport-specific)
            if (configOpts.isNotEmpty) ...[
              _Label(_matchConfigLabel[_sport] ?? 'Match Format'),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: configOpts.map((c) => _PickChip(
                  label: c,
                  selected: _matchConfig == c,
                  onTap: () => setState(() => _matchConfig = c),
                )).toList(),
              ),
              SizedBox(height: 18),
            ],

            // Registration
            _Label('Team Registration'),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    icon: Icons.verified_user_outlined,
                    title: trId('manual_approval'),
                    subtitle: 'You approve teams',
                    selected: _registration == 'MANUAL_APPROVAL',
                    onTap: () => setState(() => _registration = 'MANUAL_APPROVAL'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _ModeCard(
                    icon: Icons.public,
                    title: trId('open_registration'),
                    subtitle: 'Anyone can join',
                    selected: _registration == 'OPEN',
                    onTap: () => setState(() => _registration = 'OPEN'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),

            // Venue
            _Label('Venue'),
            SizedBox(height: 8),
            TextField(
              controller: _venueCtrl,
              decoration: _dec(context, 'Where the matches are played', Icons.location_on_outlined),
            ),
            SizedBox(height: 18),

            // Additional settings
            _Label('Additional Settings'),
            SizedBox(height: 8),
            _ToggleRow(
              icon: Icons.leaderboard_outlined,
              label: trId('points_table'),
              value: _showPoints,
              onChanged: (v) => setState(() => _showPoints = v),
            ),
            _ToggleRow(
              icon: Icons.bolt_outlined,
              label: trId('live_scores'),
              value: _showLive,
              onChanged: (v) => setState(() => _showLive = v),
            ),
            if (_sport == 'cricket')
              _ToggleRow(
                icon: Icons.sports_cricket_outlined,
                label: trId('village_wides_rule'),
                value: _villageWides,
                onChanged: (v) => setState(() => _villageWides = v),
              ),
            _ToggleRow(
              icon: Icons.card_giftcard_outlined,
              label: trId('prize_details'),
              value: _showPrize,
              onChanged: (v) => setState(() => _showPrize = v),
            ),
            if (_showPrize) ...[
              SizedBox(height: 8),
              TextField(
                controller: _prizeCtrl,
                maxLines: 2,
                decoration: _dec(context, 'e.g. Winner ₹10,000 · Runner-up ₹5,000', Icons.emoji_events_outlined),
              ),
            ],
            SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Label('Description (Markdown Supported)'),
                PopupMenuButton<String>(
                  icon: Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                  tooltip: trId('templates'),
                  onSelected: (template) {
                    setState(() {
                      if (template == 'Cricket') {
                        _descCtrl.text = '''### 🏏 Cricket Tournament Rules
**Format**: 20 Overs, Knockout
**Entry Fee**: ₹1000
**Rules**:
1. ICC T20 Rules apply.
2. Umpires decision is final.
3. Teams must report 30 mins early.''';
                      } else if (template == 'Volleyball') {
                        _descCtrl.text = '''### 🏐 Volleyball Tournament
**Format**: Best of 3 Sets, 25 Points
**Rules**:
1. Standard FIVB rules.
2. Max 8 players per squad.''';
                      } else if (template == 'Independence') {
                        _descCtrl.text = '''### 🇮🇳 Independence Day Sports
Celebrate freedom with friendly matches!
**Events**: Cricket, Tug of War, Athletics
**Prizes**: Medals and Trophies for winners.''';
                      } else if (template == 'Blood Donation') {
                        _descCtrl.text = '''### 🩸 Blood Donation Camp
**In association with**: Government Hospital
*Give blood, save a life.*
- Refreshments provided.
- Certificate of appreciation.''';
                      } else if (template == 'General') {
                        _descCtrl.text = '''### 🎉 Annual Celebration Event
Join us for our yearly gathering!
**Highlights**:
- Cultural Programs
- Sports Finals
- Prize Distribution''';
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'Cricket', child: Text(trId('cricket_tournament'))),
                    PopupMenuItem(value: 'Volleyball', child: Text(trId('volleyball_tournament'))),
                    PopupMenuItem(value: 'Independence', child: Text(trId('independence_day'))),
                    PopupMenuItem(value: 'Blood Donation', child: Text(trId('blood_donation_2'))),
                    PopupMenuItem(value: 'General', child: Text(trId('general_event'))),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 8,
              decoration: _dec(context, 'Write tournament rules, timings, and information here. You can use markdown like **bold** or *italic*.', Icons.description_outlined),
            ),
            SizedBox(height: 20),
          ],

          // Summary
          _SummaryCard(
            sport: sportOpt,
            name: _nameCtrl.text.trim(),
            numTeams: _effectiveNumTeams,
            format: _formatLabels[_format]!,
            matchConfig: _matchConfig,
            registration: _registration,
            start: _startDate,
            end: _endDate,
            venue: _venueCtrl.text.trim(),
          ),
          SizedBox(height: 14),

          // How it works
          const _HowItWorks(),
          SizedBox(height: 20),

          // Create button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _submitting
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, color: AppColors.background, size: 18),
                        SizedBox(width: 10),
                        Text(widget.tournament != null ? 'Save Changes' : 'Create Tournament',
                            style: TextStyle(color: AppColors.background, fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(trId('we_ll_generate_fixtures_automatically'),
                style: TextStyle(fontSize: 11, color: context.cTextSecondary)),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  InputDecoration _dec(BuildContext context, String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: context.cTextSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.cBorder),
        ),
        isDense: true,
      );
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.cText));
}

class _PickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PickChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : context.cSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : context.cBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : context.cText,
            )),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.10) : context.cSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : context.cBorder, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: selected ? AppColors.primary : context.cTextSecondary),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.cText)),
            SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 10.5, color: context.cTextSecondary)),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: context.cTextSecondary),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 9.5, color: context.cTextSecondary)),
                  Text(
                    date == null ? 'Select' : DateFormat('d MMM yyyy').format(date!),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: date == null ? context.cTextSecondary : context.cText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.cTextSecondary),
          SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: context.cText, fontWeight: FontWeight.w500))),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final _SportOpt sport;
  final String name;
  final int? numTeams;
  final String format;
  final String? matchConfig;
  final String registration;
  final DateTime? start, end;
  final String venue;
  const _SummaryCard({
    required this.sport,
    required this.name,
    required this.numTeams,
    required this.format,
    required this.matchConfig,
    required this.registration,
    required this.start,
    required this.end,
    required this.venue,
  });

  @override
  Widget build(BuildContext context) {
    String fmtDate(DateTime? d) => d == null ? '—' : DateFormat('d MMM').format(d);
    final rows = <(String, String)>[
      ('Sport', '${sport.emoji} ${sport.labelEn}'),
      ('Format', format),
      if (matchConfig != null) ('Match', matchConfig!),
      ('Teams', numTeams?.toString() ?? '—'),
      ('Registration', registration == 'OPEN' ? 'Open' : 'Manual'),
      ('Dates', '${fmtDate(start)} – ${fmtDate(end)}'),
      ('Venue', venue.isEmpty ? '—' : venue),
    ];
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF15201A) : const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(trId('tournament_summary'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.cText)),
            ],
          ),
          if (name.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
          SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.$1, style: TextStyle(fontSize: 12, color: context.cTextSecondary)),
                    Text(r.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.cText)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', trId('add_teams'), trId('add_teams_help')),
      ('2', trId('auto_fixture'), trId('auto_fixture_help')),
      ('3', trId('live_scores'), trId('live_scores_help')),
      ('4', trId('winner'), trId('winner_help')),
    ];
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF101A22) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trId('how_it_works_2'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  color: context.isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB))),
          SizedBox(height: 12),
          ...steps.map((s) => Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(s.$1, style: TextStyle(color: AppColors.background, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.$2, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.cText)),
                          Text(s.$3, style: TextStyle(fontSize: 11, color: context.cTextSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
