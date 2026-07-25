import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design_system/components/ds_skeleton.dart';
import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/entrance.dart';
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
        return trId('live_2');
      case 'COMPLETED':
        return trId('completed_4');
      case 'REGISTRATION_CLOSED':
        return trId('registration_closed_3');
      default:
        return trId('registration_open_3');
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'IN_PROGRESS':
        return const Color(0xFFEF4444);
      case 'COMPLETED':
        return const Color(0xFF64748B);
      case 'REGISTRATION_CLOSED':
        return const Color(0xFFF59E0B);
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
          title: Text(trId('new_chess_tournament')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: InputDecoration(labelText: trId('name'))),
              const SizedBox(height: 8),
              TextField(controller: descC, decoration: InputDecoration(labelText: trId('description_2'))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deadline == null
                          ? trId('registration_deadline_optional')
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
                    child: Text(trId('pick')),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(trId('cancel_2'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(trId('create'), style: const TextStyle(color: Colors.white)),
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
              content: Text(trId('could_not_create')),
              backgroundColor: AppColors.accent));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(title: Text(trId('chess_tournaments'))),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _createDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(trId('create'), style: const TextStyle(color: Colors.white)),
            )
          : null,
      body: _items == null && !_error
          ? const DSSkeletonList()
          : _error
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: _load, child: Text(trId('retry_2'))),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: (_items!.isEmpty)
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          const Center(child: Text('♟️', style: TextStyle(fontSize: 56))),
                          const SizedBox(height: 12),
                          Center(child: Text(trId('no_tournaments_yet'), style: TextStyle(color: context.cTextSecondary))),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _items!.length,
                          itemBuilder: (_, i) {
                            final t = _items![i];
                            return FadeSlideIn(
                              delay: Duration(milliseconds: (i * 45).clamp(0, 400)),
                              child: Container(
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
                                    Text('${t.entryCount} ${trId('players')}', style: TextStyle(fontSize: 12, color: context.cTextSecondary)),
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
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
