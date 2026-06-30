import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../auth/presentation/bloc/auth_bloc.dart';
import '../auth/presentation/bloc/auth_state.dart';
import 'chess_tournament_api.dart';
import 'chess_tournament_models.dart';
import 'chess_tournament_detail_screen.dart';

class ChessTournamentListScreen extends StatefulWidget {
  const ChessTournamentListScreen({super.key});

  @override
  State<ChessTournamentListScreen> createState() => _ChessTournamentListScreenState();
}

class _ChessTournamentListScreenState extends State<ChessTournamentListScreen> {
  List<ChessTournament>? _items;
  bool _error = false;

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
      final list = await ChessTournamentApi.list();
      if (mounted) setState(() { _items = list; _error = false; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'IN_PROGRESS':
        return tr(en: 'Live', ta: 'நேரலை', hi: 'लाइव', ml: 'ലൈവ്');
      case 'COMPLETED':
        return tr(en: 'Completed', ta: 'முடிந்தது', hi: 'समाप्त', ml: 'പൂർത്തിയായി');
      default:
        return tr(en: 'Registration Open', ta: 'பதிவு திறந்துள்ளது', hi: 'पंजीकरण खुला', ml: 'രജിസ്ട്രേഷൻ തുറന്നു');
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'IN_PROGRESS':
        return const Color(0xFFEF4444);
      case 'COMPLETED':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF16A34A);
    }
  }

  Future<void> _createDialog() async {
    final nameC = TextEditingController();
    final descC = TextEditingController();
    DateTime? deadline;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(tr(en: 'New Chess Tournament', ta: 'புதிய சதுரங்கப் போட்டி', hi: 'नया शतरंज टूर्नामेंट', ml: 'പുതിയ ചെസ് ടൂർണമെന്റ്')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: InputDecoration(labelText: tr(en: 'Name', ta: 'பெயர்', hi: 'नाम', ml: 'പേര്'))),
              const SizedBox(height: 8),
              TextField(controller: descC, decoration: InputDecoration(labelText: tr(en: 'Description', ta: 'விளக்கம்', hi: 'विवरण', ml: 'വിവരണം'))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deadline == null
                          ? tr(en: 'Registration deadline (optional)', ta: 'பதிவு இறுதி தேதி', hi: 'पंजीकरण अंतिम तिथि', ml: 'രജിസ്ട്രേഷൻ അവസാന തീയതി')
                          : '${deadline!.day}/${deadline!.month}/${deadline!.year}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: now.add(const Duration(days: 7)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (d != null) setSt(() => deadline = d);
                    },
                    child: Text(tr(en: 'Pick', ta: 'தேர்வு', hi: 'चुनें', ml: 'തിരഞ്ഞെടുക്കുക')),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(en: 'Cancel', ta: 'ரத்து', hi: 'रद्द', ml: 'റദ്ദാക്കുക'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(tr(en: 'Create', ta: 'உருவாக்கு', hi: 'बनाएं', ml: 'സൃഷ്ടിക്കുക'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (created == true && nameC.text.trim().isNotEmpty) {
      try {
        await ChessTournamentApi.create(
          name: nameC.text.trim(),
          description: descC.text.trim(),
          registrationDeadline: deadline?.toUtc().toIso8601String(),
        );
        _load();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr(en: 'Could not create', ta: 'உருவாக்க முடியவில்லை', hi: 'नहीं बना सका', ml: 'സൃഷ്ടിക്കാനായില്ല')),
              backgroundColor: AppColors.accent));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(title: Text(tr(en: 'Chess Tournaments', ta: 'சதுரங்கப் போட்டிகள்', hi: 'शतरंज टूर्नामेंट', ml: 'ചെസ് ടൂർണമെന്റുകൾ'))),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _createDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(tr(en: 'Create', ta: 'உருவாக்கு', hi: 'बनाएं', ml: 'സൃഷ്ടിക്കുക'), style: const TextStyle(color: Colors.white)),
            )
          : null,
      body: _items == null && !_error
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: _load, child: Text(tr(en: 'Retry', ta: 'மீண்டும்', hi: 'पुनः', ml: 'വീണ്ടും'))),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: (_items!.isEmpty)
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          const Center(child: Text('♟️', style: TextStyle(fontSize: 56))),
                          const SizedBox(height: 12),
                          Center(child: Text(tr(en: 'No tournaments yet', ta: 'இன்னும் போட்டிகள் இல்லை', hi: 'अभी कोई टूर्नामेंट नहीं', ml: 'ഇതുവരെ ടൂർണമെന്റുകളില്ല'), style: TextStyle(color: context.cTextSecondary))),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _items!.length,
                          itemBuilder: (_, i) {
                            final t = _items![i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: context.cSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.cBorder),
                                boxShadow: context.isDark ? null : AppTheme.cardShadow,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: const Text('♟️', style: TextStyle(fontSize: 28)),
                                title: Text(t.name, style: TextStyle(fontWeight: FontWeight.w800, color: context.cText)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: _statusColor(t.status).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                                      child: Text(_statusLabel(t.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(t.status))),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${t.entryCount} ${tr(en: 'players', ta: 'வீரர்கள்', hi: 'खिलाड़ी', ml: 'കളിക്കാർ')}', style: TextStyle(fontSize: 12, color: context.cTextSecondary)),
                                    if (t.isRegistered) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                                    ],
                                  ]),
                                ),
                                trailing: Icon(Icons.chevron_right, color: context.cTextSecondary),
                                onTap: () async {
                                  await Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ChessTournamentDetailScreen(tournamentId: t.id),
                                  ));
                                  _load();
                                },
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
