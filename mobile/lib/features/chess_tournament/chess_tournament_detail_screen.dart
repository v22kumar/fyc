import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/tr.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../service_locator.dart';
import '../auth/presentation/bloc/auth_bloc.dart';
import '../auth/presentation/bloc/auth_state.dart';
import 'chess_tournament_api.dart';
import 'chess_tournament_models.dart';

class ChessTournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  const ChessTournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<ChessTournamentDetailScreen> createState() => _State();
}

class _State extends State<ChessTournamentDetailScreen> {
  ChessTournamentDetail? _t;
  bool _error = false;
  bool _busy = false;

  String? get _uid {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s.user.id : null;
  }

  bool get _isAdmin {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.isAdmin;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ChessTournamentApi.detail(widget.tournamentId);
      if (mounted) setState(() { _t = d; _error = false; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? failMsg}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(failMsg ?? tr(en: 'Action failed. Try again.', ta: 'செயல் தோல்வி.', hi: 'क्रिया विफल।', ml: 'പ്രവർത്തനം പരാജയപ്പെട്ടു.')),
            backgroundColor: AppColors.accent));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _playMatch(BracketMatch m) async {
    final color = (m.playerA?.id == _uid) ? 'white' : 'black';
    try {
      final gameId = (m.gameId != null && m.gameId!.isNotEmpty)
          ? m.gameId!
          : await ChessTournamentApi.play(widget.tournamentId, m.id);
      final token = await sl<LocalStorage>().getToken() ?? '';
      if (!mounted) return;
      await context.push('/chess/online/$gameId', extra: {'token': token, 'color': color});
      _load();
    } catch (e) {
      // 409 = opponent not ready yet; anything else is a generic failure.
      final waiting = e.toString().contains('409');
      _snack(waiting
          ? tr(en: 'Waiting for your opponent to be ready.', ta: 'எதிராளி தயாராவதற்குக் காத்திருக்கிறது.', hi: 'प्रतिद्वंद्वी के तैयार होने की प्रतीक्षा।', ml: 'എതിരാളി തയ്യാറാകാൻ കാത്തിരിക്കുന്നു.')
          : tr(en: 'Could not open the board.', ta: 'பலகையைத் திறக்க முடியவில்லை.', hi: 'बोर्ड नहीं खुला।', ml: 'ബോർഡ് തുറക്കാനായില്ല.'));
    }
  }

  String _roundName(int r, int total) {
    if (r == total) return tr(en: 'Final', ta: 'இறுதிப் போட்டி', hi: 'फ़ाइनल', ml: 'ഫൈനൽ');
    if (r == total - 1) return tr(en: 'Semi-finals', ta: 'அரையிறுதி', hi: 'सेमीफ़ाइनल', ml: 'സെമിഫൈനൽ');
    if (r == total - 2) return tr(en: 'Quarter-finals', ta: 'காலிறுதி', hi: 'क्वार्टरफ़ाइनल', ml: 'ക്വാർട്ടർ ഫൈനൽ');
    return '${tr(en: 'Round', ta: 'சுற்று', hi: 'राउंड', ml: 'റൗണ്ട്')} $r';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(title: Text(_t?.name ?? tr(en: 'Tournament', ta: 'போட்டி', hi: 'टूर्नामेंट', ml: 'ടൂർണമെന്റ്'))),
      body: _t == null && !_error
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Center(child: ElevatedButton(onPressed: _load, child: Text(tr(en: 'Retry', ta: 'மீண்டும்', hi: 'पुनः', ml: 'വീണ്ടും'))))
              : RefreshIndicator(onRefresh: _load, child: _body(_t!)),
    );
  }

  Widget _body(ChessTournamentDetail t) {
    final children = <Widget>[];

    if (t.champion != null) children.add(_championBanner(t));

    if (t.description != null && t.description!.isNotEmpty) {
      children.add(Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t.description!, style: TextStyle(color: context.cTextSecondary, height: 1.4))));
    }

    if (t.isOpen || t.isClosed) children.add(_registrationCard(t));
    if (_isAdmin && (t.isOpen || t.isClosed) && t.pendingEntries.isNotEmpty) {
      children.add(_approvalsCard(t));
    }

    // Bracket
    if (t.matches.isNotEmpty) {
      children.add(const SizedBox(height: 16));
      children.add(Text(tr(en: 'Tournament Bracket', ta: 'போட்டி வரைபடம்', hi: 'टूर्नामेंट ब्रैकेट', ml: 'ടൂർണമെന്റ് ബ്രാക്കറ്റ്'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cText)));
      children.add(const SizedBox(height: 16));
      
      final bracketWidget = SizedBox(
        height: 600, // Fixed height for panning area
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: context.cBackground,
              border: Border.all(color: context.cBorder),
            ),
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(120),
              minScale: 0.3,
              maxScale: 2.0,
              // We could use a TransformationController to auto-focus on t.currentRound here
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _buildHorizontalBracketGraph(t),
              ),
            ),
          ),
        ),
      );
      children.add(bracketWidget);
    }

    // Manager: Start Next Round
    if (_isAdmin && t.inProgress) {
      final btn = _nextRoundButton(t);
      if (btn != null) children.add(Padding(padding: const EdgeInsets.only(top: 16), child: btn));
    }

    return ListView(padding: const EdgeInsets.all(16), children: children);
  }

  Widget _championBanner(ChessTournamentDetail t) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF0C75E)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          const Text('🏆', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(en: 'Champion', ta: 'வெற்றியாளர்', hi: 'चैंपियन', ml: 'ചാമ്പ്യൻ'), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(t.champion!.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ])),
        ]),
      );

  Widget _roundBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      );

  // ── Registration / manager controls ─────────────────────────────────────────
  Widget _registrationCard(ChessTournamentDetail t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${t.entryCount} ${tr(en: 'approved', ta: 'அங்கீகரிக்கப்பட்டது', hi: 'स्वीकृत', ml: 'അംഗീകരിച്ചു')}',
              style: TextStyle(fontWeight: FontWeight.w800, color: context.cText, fontSize: 15)),
          if (t.pendingCount > 0) ...[
            const SizedBox(width: 8),
            _roundBadge('${t.pendingCount} ${tr(en: 'pending', ta: 'நிலுவை', hi: 'लंबित', ml: 'തീർപ്പാക്കാത്തത്')}', const Color(0xFFF59E0B)),
          ],
          const Spacer(),
          if (t.isClosed) _roundBadge(tr(en: 'Registration closed', ta: 'பதிவு மூடப்பட்டது', hi: 'पंजीकरण बंद', ml: 'രജിസ്ട്രേഷൻ അടച്ചു'), context.cTextSecondary),
        ]),
        const SizedBox(height: 12),

        // Player-facing registration state.
        if (!t.isRegistered && t.isOpen)
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _busy ? null : () => _run(() => ChessTournamentApi.register(t.id)),
            icon: const Icon(Icons.how_to_reg, color: Colors.white),
            label: Text(tr(en: 'Register to Play', ta: 'விளையாட பதிவு செய்', hi: 'खेलने के लिए पंजीकरण', ml: 'കളിക്കാൻ രജിസ്റ്റർ ചെയ്യുക'), style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
          ))
        else if (t.isRegistered)
          _myStatusRow(t.myStatus),

        // Manager controls.
        if (_isAdmin) ...[
          const SizedBox(height: 10),
          if (t.isOpen)
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(() async { await ChessTournamentApi.closeRegistration(t.id); }),
              icon: const Icon(Icons.lock_clock),
              label: Text(tr(en: 'Close Registration', ta: 'பதிவை மூடு', hi: 'पंजीकरण बंद करें', ml: 'രജിസ്ട്രേഷൻ അടയ്ക്കുക')),
            )),
          if (t.isClosed) ...[
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _run(() async { await ChessTournamentApi.start(t.id); },
                  failMsg: tr(en: 'Need at least 2 approved players.', ta: 'குறைந்தது 2 வீரர்கள் தேவை.', hi: 'कम से कम 2 स्वीकृत खिलाड़ी चाहिए।', ml: 'കുറഞ്ഞത് 2 കളിക്കാർ വേണം.')),
              icon: const Icon(Icons.play_circle_fill, color: Colors.white),
              label: Text(tr(en: 'Start Tournament & Draw Bracket', ta: 'போட்டியைத் தொடங்கு', hi: 'टूर्नामेंट शुरू करें', ml: 'ടൂർണമെന്റ് ആരംഭിക്കുക'), style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: TextButton.icon(
              onPressed: _busy ? null : () => _run(() async { await ChessTournamentApi.reopenRegistration(t.id); }),
              icon: const Icon(Icons.lock_open, size: 18),
              label: Text(tr(en: 'Reopen Registration', ta: 'பதிவை மீண்டும் திற', hi: 'पंजीकरण फिर खोलें', ml: 'രജിസ്ട്രേഷൻ വീണ്ടും തുറക്കുക')),
            )),
          ],
        ],
      ]),
    );
  }

  Widget _myStatusRow(String? status) {
    late IconData icon;
    late Color color;
    late String label;
    switch (status) {
      case 'APPROVED':
        icon = Icons.check_circle; color = const Color(0xFF16A34A);
        label = tr(en: "You're approved — get ready!", ta: 'நீங்கள் அங்கீகரிக்கப்பட்டீர்கள்!', hi: 'आप स्वीकृत हैं!', ml: 'നിങ്ങൾ അംഗീകരിക്കപ്പെട്ടു!');
        break;
      case 'REJECTED':
        icon = Icons.cancel; color = AppColors.accent;
        label = tr(en: 'Not accepted this time', ta: 'இம்முறை ஏற்கப்படவில்லை', hi: 'इस बार स्वीकार नहीं', ml: 'ഇത്തവണ സ്വീകരിച്ചില്ല');
        break;
      default:
        icon = Icons.hourglass_top; color = const Color(0xFFF59E0B);
        label = tr(en: 'Registered — waiting for approval', ta: 'பதிவு — அங்கீகாரத்திற்குக் காத்திருக்கிறது', hi: 'पंजीकृत — अनुमोदन प्रतीक्षित', ml: 'രജിസ്റ്റർ ചെയ്തു — അംഗീകാരം കാത്തിരിക്കുന്നു');
    }
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(color: context.cText, fontWeight: FontWeight.w600))),
    ]);
  }

  Widget _approvalsCard(ChessTournamentDetail t) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(en: 'Pending approvals', ta: 'நிலுவையிலுள்ள ஒப்புதல்கள்', hi: 'लंबित अनुमोदन', ml: 'തീർപ്പാക്കാത്ത അംഗീകാരങ്ങൾ'),
            style: TextStyle(fontWeight: FontWeight.w800, color: context.cText)),
        const SizedBox(height: 4),
        Text(tr(en: 'Only approved players enter the bracket.', ta: 'அங்கீகரிக்கப்பட்ட வீரர்கள் மட்டுமே பங்கேற்பர்.', hi: 'केवल स्वीकृत खिलाड़ी शामिल होंगे।', ml: 'അംഗീകരിച്ച കളിക്കാർ മാത്രം.'),
            style: TextStyle(fontSize: 12, color: context.cTextSecondary)),
        const SizedBox(height: 8),
        ...t.pendingEntries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(e.name, style: TextStyle(color: context.cText, fontWeight: FontWeight.w600))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: tr(en: 'Approve', ta: 'அங்கீகரி', hi: 'स्वीकृत', ml: 'അംഗീകരിക്കുക'),
                  onPressed: _busy ? null : () => _run(() => ChessTournamentApi.decide(t.id, e.id, true)),
                  icon: const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: tr(en: 'Reject', ta: 'நிராகரி', hi: 'अस्वीकार', ml: 'നിരസിക്കുക'),
                  onPressed: _busy ? null : () => _run(() => ChessTournamentApi.decide(t.id, e.id, false)),
                  icon: Icon(Icons.cancel, color: AppColors.accent),
                ),
              ]),
            )),
      ]),
    );
  }

  Widget? _nextRoundButton(ChessTournamentDetail t) {
    if (t.currentRound < 1 || t.currentRound >= t.rounds) return null;
    // Enable only when every match in the current round is decided.
    final cur = t.matches.where((m) => m.round == t.currentRound);
    final allDecided = cur.every((m) => m.winnerId != null || m.status == 'BYE');
    return SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: (_busy || !allDecided) ? null : () => _run(() async { await ChessTournamentApi.nextRound(t.id); },
          failMsg: tr(en: 'Finish the current round first.', ta: 'முதலில் இந்தச் சுற்றை முடிக்கவும்.', hi: 'पहले वर्तमान राउंड पूरा करें।', ml: 'ആദ്യം ഈ റൗണ്ട് പൂർത്തിയാക്കുക.')),
      icon: const Icon(Icons.skip_next, color: Colors.white),
      label: Text(allDecided
          ? '${tr(en: 'Start', ta: 'தொடங்கு', hi: 'शुरू', ml: 'ആരംഭിക്കുക')} ${_roundName(t.currentRound + 1, t.rounds)}'
          : tr(en: 'Waiting for round to finish', ta: 'சுற்று முடிய காத்திருக்கிறது', hi: 'राउंड समाप्ति प्रतीक्षित', ml: 'റൗണ്ട് പൂർത്തിയാകാൻ കാത്തിരിക്കുന്നു'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(backgroundColor: allDecided ? AppColors.primary : context.cTextSecondary, padding: const EdgeInsets.symmetric(vertical: 12)),
    ));
  }

  // ── Match card ───────────────────────────────────────────────────────────────
  Widget _matchCard(ChessTournamentDetail t, BracketMatch m) {
    final iAmIn = _uid != null && (m.playerA?.id == _uid || m.playerB?.id == _uid);
    final decided = m.winnerId != null;
    final bothSet = m.playerA != null && m.playerB != null;
    final adminCanDecide = _isAdmin && bothSet && !decided;
    // Organizer can choose app vs in-person for the last two rounds (SF/final).
    final showConductToggle = _isAdmin && bothSet && !decided && m.round >= t.rounds - 1;

    Widget side(PlayerRef? p, bool isWinner) => Expanded(
          child: Row(children: [
            if (isWinner) const Padding(padding: EdgeInsets.only(right: 4), child: Text('👑', style: TextStyle(fontSize: 14))),
            Expanded(child: Text(p?.name ?? (m.status == 'BYE' ? tr(en: 'Bye', ta: 'பை', hi: 'बाई', ml: 'ബൈ') : tr(en: 'TBD', ta: 'பின்னர்', hi: 'बाद में', ml: 'പിന്നീട്')),
                style: TextStyle(fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500, color: p == null ? context.cTextSecondary : context.cText), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        );

    return Container(
      // Removing bottom margin so it centers perfectly in the bracket graph
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          side(m.playerA, decided && m.winnerId == m.playerA?.id),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(tr(en: 'vs', ta: 'எதிராக', hi: 'बनाम', ml: 'vs'), style: TextStyle(fontSize: 11, color: context.cTextSecondary))),
          side(m.playerB, decided && m.winnerId == m.playerB?.id),
        ]),

        if (showConductToggle) ...[
          const SizedBox(height: 10),
          Row(children: [
            Text('${tr(en: 'Conduct', ta: 'நடத்தை', hi: 'संचालन', ml: 'നടത്തിപ്പ്')}:', style: TextStyle(fontSize: 11, color: context.cTextSecondary)),
            const SizedBox(width: 8),
            _conductChip(tr(en: 'In App', ta: 'ஆப்பில்', hi: 'ऐप में', ml: 'ആപ്പിൽ'), !m.isPhysical,
                () => _run(() => ChessTournamentApi.setConduct(t.id, m.id, 'APP'))),
            const SizedBox(width: 6),
            _conductChip(tr(en: 'In Person', ta: 'நேரில்', hi: 'व्यक्तिगत', ml: 'നേരിട്ട്'), m.isPhysical,
                () => _pickPhysical(t, m)),
          ]),
        ],

        // Physical logistics.
        if (m.isPhysical && !decided) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.groups_rounded, size: 15, color: context.cTextSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text(
                m.venue != null && m.venue!.isNotEmpty
                    ? '${tr(en: 'In person', ta: 'நேரில்', hi: 'व्यक्तिगत', ml: 'നേരിട്ട്')} · ${m.venue}'
                    : tr(en: 'Played in person', ta: 'நேரில் விளையாடப்படுகிறது', hi: 'व्यक्तिगत रूप से खेला गया', ml: 'നേരിട്ട് കളിക്കുന്നു'),
                style: TextStyle(fontSize: 11.5, color: context.cTextSecondary, fontStyle: FontStyle.italic))),
          ]),
        ],

        // Player interaction for online matches.
        if (iAmIn && !m.isPhysical && !decided) _playArea(t, m),

        // Round-not-started hint (activated flag false, both players known).
        if (iAmIn && !m.activated && bothSet && !decided) ...[
          const SizedBox(height: 8),
          Text(tr(en: 'Waiting for the organizer to start this round.', ta: 'இந்தச் சுற்றைத் தொடங்க அமைப்பாளருக்குக் காத்திருக்கிறது.', hi: 'आयोजक द्वारा राउंड शुरू करने की प्रतीक्षा।', ml: 'സംഘാടകൻ റൗണ്ട് ആരംഭിക്കാൻ കാത്തിരിക്കുന്നു.'),
              style: TextStyle(fontSize: 11.5, color: context.cTextSecondary, fontStyle: FontStyle.italic)),
        ],

        if (adminCanDecide) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _busy ? null : () => _run(() => ChessTournamentApi.reportResult(t.id, m.id, m.playerA!.id)),
              child: Text('${tr(en: 'Win', ta: 'வெற்றி', hi: 'जीत', ml: 'ജയം')}: ${m.playerA!.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: _busy ? null : () => _run(() => ChessTournamentApi.reportResult(t.id, m.id, m.playerB!.id)),
              child: Text('${tr(en: 'Win', ta: 'வெற்றி', hi: 'जीत', ml: 'ജയം')}: ${m.playerB!.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            )),
          ]),
        ],
      ]),
    );
  }

  /// The online play/ready control for a player in an activated, undecided match.
  Widget _playArea(ChessTournamentDetail t, BracketMatch m) {
    if (!m.activated || !(m.playerA != null && m.playerB != null)) return const SizedBox.shrink();
    if (m.status == 'LIVE') {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _busy ? null : () => _playMatch(m),
          icon: const Icon(Icons.sports_esports, color: Colors.white, size: 18),
          label: Text(tr(en: 'Resume Match', ta: 'தொடரவும்', hi: 'फिर शुरू करें', ml: 'തുടരുക'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 10)),
        )),
      );
    }
    if (m.status != 'READY') return const SizedBox.shrink();

    final iAmReady = m.readyFor(_uid);
    final oppReady = m.opponentReadyFor(_uid);

    if (!iAmReady) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _busy ? null : () => _run(() => ChessTournamentApi.markReady(t.id, m.id)),
          icon: const Icon(Icons.check, color: Colors.white, size: 18),
          label: Text(tr(en: "I'm Ready", ta: 'நான் தயார்', hi: 'मैं तैयार हूँ', ml: 'ഞാൻ തയ്യാർ'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(vertical: 10)),
        )),
      );
    }
    if (!oppReady) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(tr(en: "You're ready — waiting for your opponent…", ta: 'நீங்கள் தயார் — எதிராளிக்குக் காத்திருக்கிறது…', hi: 'आप तैयार — प्रतिद्वंद्वी की प्रतीक्षा…', ml: 'നിങ്ങൾ തയ്യാർ — എതിരാളിയെ കാത്തിരിക്കുന്നു…'),
              style: TextStyle(fontSize: 12, color: context.cTextSecondary))),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _busy ? null : () => _playMatch(m),
        icon: const Icon(Icons.sports_esports, color: Colors.white, size: 18),
        label: Text(tr(en: 'Play Your Match', ta: 'உங்கள் ஆட்டத்தை விளையாடு', hi: 'अपना मैच खेलें', ml: 'നിങ്ങളുടെ മത്സരം കളിക്കുക'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 10)),
      )),
    );
  }

  Future<void> _pickPhysical(ChessTournamentDetail t, BracketMatch m) async {
    final ctrl = TextEditingController(text: m.venue ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(en: 'Play in person', ta: 'நேரில் விளையாடு', hi: 'व्यक्तिगत रूप से खेलें', ml: 'നേരിട്ട് കളിക്കുക')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: tr(en: 'Venue (optional)', ta: 'இடம் (விருப்பம்)', hi: 'स्थान (वैकल्पिक)', ml: 'വേദി (ഓപ്ഷണൽ)'),
            hintText: tr(en: 'e.g. FYC Club Hall', ta: 'எ.கா. FYC மண்டபம்', hi: 'जैसे FYC हॉल', ml: 'ഉദാ. FYC ഹാൾ'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(en: 'Cancel', ta: 'ரத்து', hi: 'रद्द', ml: 'റദ്ദാക്കുക'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(en: 'Confirm', ta: 'உறுதி', hi: 'पुष्टि', ml: 'സ്ഥിരീകരിക്കുക'))),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => ChessTournamentApi.setConduct(t.id, m.id, 'PHYSICAL', venue: ctrl.text.trim()));
    }
  }

  Widget _conductChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : context.cBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : context.cTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalBracketGraph(ChessTournamentDetail t) {
    final byRound = <int, List<BracketMatch>>{};
    for (final m in t.matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }
    final rounds = byRound.keys.toList()..sort();
    
    const double cardWidth = 280;
    const double horizontalSpacing = 60;
    const double verticalSpacing = 20;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rounds.map((r) {
        final matches = byRound[r]!..sort((a, b) => a.slot.compareTo(b.slot));
        
        final double baseCellHeight = 160 + verticalSpacing;
        final double cellHeight = baseCellHeight * (1 << (r - 1));

        return Container(
          width: cardWidth,
          margin: EdgeInsets.only(right: r == rounds.last ? 0 : horizontalSpacing),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Header
              Container(
                height: 40,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: r <= t.currentRound ? AppColors.primary.withOpacity(0.1) : context.cBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: r <= t.currentRound ? AppColors.primary : context.cBorder),
                ),
                child: Text(
                  _roundName(r, t.rounds),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: r <= t.currentRound ? AppColors.primary : context.cTextSecondary,
                  ),
                ),
              ),
              ...matches.map((m) {
                return SizedBox(
                  height: cellHeight,
                  child: Center(
                    child: SizedBox(
                      width: cardWidth,
                      child: _matchCard(t, m),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }
}
