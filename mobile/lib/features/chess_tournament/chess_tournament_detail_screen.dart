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

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(en: 'Action failed. Try again.', ta: 'செயல் தோல்வி.', hi: 'क्रिया विफल।', ml: 'പ്രവർത്തനം പരാജയപ്പെട്ടു.')),
            backgroundColor: AppColors.accent));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(en: 'Could not open the board.', ta: 'பலகையைத் திறக்க முடியவில்லை.', hi: 'बोर्ड नहीं खुला।', ml: 'ബോർഡ് തുറക്കാനായില്ല.')),
            backgroundColor: AppColors.accent));
      }
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
    final isOpen = t.status == 'REGISTRATION_OPEN';
    final children = <Widget>[];

    if (t.champion != null) {
      children.add(Container(
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
      ));
    }

    if (t.description != null && t.description!.isNotEmpty) {
      children.add(Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t.description!, style: TextStyle(color: context.cTextSecondary, height: 1.4))));
    }

    if (isOpen) {
      children.add(Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.cBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t.entryCount} ${tr(en: 'players registered', ta: 'வீரர்கள் பதிவு', hi: 'खिलाड़ी पंजीकृत', ml: 'കളിക്കാർ രജിസ്റ്റർ ചെയ്തു')}', style: TextStyle(fontWeight: FontWeight.w700, color: context.cText)),
          const SizedBox(height: 12),
          if (!t.isRegistered)
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _run(() => ChessTournamentApi.register(t.id)),
              icon: const Icon(Icons.how_to_reg, color: Colors.white),
              label: Text(tr(en: 'Register to Play', ta: 'விளையாட பதிவு செய்', hi: 'खेलने के लिए पंजीकरण', ml: 'കളിക്കാൻ രജിസ്റ്റർ ചെയ്യുക'), style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
            ))
          else
            Row(children: [const Icon(Icons.check_circle, color: Color(0xFF16A34A)), const SizedBox(width: 8), Text(tr(en: "You're registered", ta: 'நீங்கள் பதிவு செய்துள்ளீர்கள்', hi: 'आप पंजीकृत हैं', ml: 'നിങ്ങൾ രജിസ്റ്റർ ചെയ്തു'), style: TextStyle(color: context.cText, fontWeight: FontWeight.w600))]),
          if (_isAdmin) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(() async { await ChessTournamentApi.start(t.id); }),
              icon: const Icon(Icons.play_circle_fill),
              label: Text(tr(en: 'Start Tournament & Draw Bracket', ta: 'போட்டியைத் தொடங்கு', hi: 'टूर्नामेंट शुरू करें', ml: 'ടൂർണമെന്റ് ആരംഭിക്കുക')),
            )),
          ],
        ]),
      ));
    }

    // Bracket
    final byRound = <int, List<BracketMatch>>{};
    for (final m in t.matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }
    final rounds = byRound.keys.toList()..sort();
    for (final r in rounds) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(_roundName(r, t.rounds), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.cText)),
      ));
      for (final m in byRound[r]!) {
        children.add(_matchCard(t, m));
      }
    }

    return ListView(padding: const EdgeInsets.all(16), children: children);
  }

  Widget _matchCard(ChessTournamentDetail t, BracketMatch m) {
    final iAmIn = _uid != null && (m.playerA?.id == _uid || m.playerB?.id == _uid);
    final canPlay = iAmIn && (m.status == 'READY' || m.status == 'LIVE') && m.winnerId == null;
    final adminCanDecide = _isAdmin && m.playerA != null && m.playerB != null && m.winnerId == null;

    Widget side(PlayerRef? p, bool isWinner) => Expanded(
          child: Row(children: [
            if (isWinner) const Padding(padding: EdgeInsets.only(right: 4), child: Text('👑', style: TextStyle(fontSize: 14))),
            Expanded(child: Text(p?.name ?? (m.status == 'BYE' ? tr(en: 'Bye', ta: 'பை', hi: 'बाई', ml: 'ബൈ') : tr(en: 'TBD', ta: 'பின்னர்', hi: 'बाद में', ml: 'പിന്നീട്')),
                style: TextStyle(fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500, color: p == null ? context.cTextSecondary : context.cText), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: context.cSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.cBorder)),
      child: Column(children: [
        Row(children: [
          side(m.playerA, m.winnerId != null && m.winnerId == m.playerA?.id),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(tr(en: 'vs', ta: 'எதிராக', hi: 'बनाम', ml: 'vs'), style: TextStyle(fontSize: 11, color: context.cTextSecondary))),
          side(m.playerB, m.winnerId != null && m.winnerId == m.playerB?.id),
        ]),
        if (canPlay) ...[
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _busy ? null : () => _playMatch(m),
            icon: const Icon(Icons.sports_esports, color: Colors.white, size: 18),
            label: Text(m.status == 'LIVE' ? tr(en: 'Resume Match', ta: 'தொடரவும்', hi: 'फिर शुरू करें', ml: 'തുടരുക') : tr(en: 'Play Your Match', ta: 'உங்கள் ஆட்டத்தை விளையாடு', hi: 'अपना मैच खेलें', ml: 'നിങ്ങളുടെ മത്സരം കളിക്കുക'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 10)),
          )),
        ],
        if (adminCanDecide) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: _busy ? null : () => _run(() => ChessTournamentApi.reportResult(t.id, m.id, m.playerA!.id).then((_) {})),
              child: Text('${tr(en: 'Win', ta: 'வெற்றி', hi: 'जीत', ml: 'ജയം')}: ${m.playerA!.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: _busy ? null : () => _run(() => ChessTournamentApi.reportResult(t.id, m.id, m.playerB!.id).then((_) {})),
              child: Text('${tr(en: 'Win', ta: 'வெற்றி', hi: 'जीत', ml: 'ജയം')}: ${m.playerB!.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            )),
          ]),
        ],
      ]),
    );
  }
}
