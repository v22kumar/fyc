import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/ds_skeleton.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/entrance.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/tournament_entities.dart';
import '../../domain/repositories/tournament_repository.dart';
import '../bloc/tournament_bloc.dart';

/// Every tournament, one card each — and the organiser's create flow.
class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  bool get _isAdmin {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.isAdmin;
  }

  @override
  void initState() {
    super.initState();
    context.read<TournamentListBloc>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(title: Text(trId('chess_tournaments'))),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _createDialog(context),
              backgroundColor: AppColors.primary,
              icon: Icon(Icons.add, color: AppColors.background),
              label: Text(trId('create'),
                  style: TextStyle(color: AppColors.background)),
            )
          : null,
      body: BlocBuilder<TournamentListBloc, TournamentListState>(
        builder: (context, state) {
          if (state.loading && state.items.isEmpty) {
            return const DSSkeletonList();
          }
          if (state.failure != null && state.items.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.wifi_off_rounded,
                    size: 40, color: AppColors.textSecondary),
                const SizedBox(height: 8),
                Text(state.failure!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                FilledButton(
                    onPressed: () =>
                        context.read<TournamentListBloc>().load(),
                    child: Text(trId('retry_2'))),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<TournamentListBloc>().load(),
            child: state.items.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 80),
                    Center(
                        child: Icon(Icons.castle_rounded,
                            size: 56, color: context.cTextSecondary)),
                    const SizedBox(height: 12),
                    Center(
                        child: Text(trId('no_tournaments_yet'),
                            style:
                                TextStyle(color: context.cTextSecondary))),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: state.items.length,
                    itemBuilder: (_, i) => FadeSlideIn(
                      delay:
                          Duration(milliseconds: (i * 45).clamp(0, 400)),
                      child: _card(context, state.items[i]),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, Tournament t) {
    final (label, color) = switch (t.status) {
      TournamentStatus.inProgress => (trId('live_2'), const Color(0xFFEF4444)),
      TournamentStatus.completed => (
          trId('completed_4'),
          const Color(0xFF64748B)
        ),
      TournamentStatus.closed => (
          trId('registration_closed_3'),
          const Color(0xFFF59E0B)
        ),
      _ => (trId('registration_open_3'), const Color(0xFF16A34A)),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cBorder),
        boxShadow: context.isDark ? null : AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // Drawn, not the ♟️ emoji — tofu on the handsets this club uses.
        leading: Icon(Icons.castle_rounded,
            size: 30, color: AppColors.primary),
        title: Text(t.name,
            style:
                TextStyle(fontWeight: FontWeight.w800, color: context.cText)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
              Text('${t.entryCount} ${trId('players')}',
                  style: TextStyle(
                      fontSize: 12, color: context.cTextSecondary)),
              // The deadline, on the card where it decides whether to hurry.
              if (t.isOpen && t.registrationDeadline != null)
                Text(
                  trId('closes_on', {
                    'date':
                        DateFormat('d MMM').format(t.registrationDeadline!)
                  }),
                  style: TextStyle(
                      fontSize: 12, color: context.cTextSecondary),
                ),
              if (t.champion != null)
                Text('${trId('champion')}: ${t.champion!.name}',
                    style: TextStyle(
                        fontSize: 12, color: context.cTextSecondary)),
              if (t.isRegistered)
                const Icon(Icons.check_circle,
                    size: 14, color: Color(0xFF16A34A)),
            ],
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: context.cTextSecondary),
        onTap: () async {
          final bloc = context.read<TournamentListBloc>();
          await context.push('/chess/tournaments/${t.id}');
          // Something may have changed in there — a registration, a result.
          bloc.load();
        },
      ),
    );
  }

  Future<void> _createDialog(BuildContext context) async {
    // Captured before any await, and the messenger too — a snackbar shown
    // through a context that survived an async gap is the lint's point.
    final listBloc = context.read<TournamentListBloc>();
    final repo = context.read<TournamentRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final nameC = TextEditingController();
    final descC = TextEditingController();
    DateTime? deadline;
    var timeControl = 'rapid_10_0';
    var tcOptions = <({String value, String label})>[
      (value: 'rapid_10_0', label: trId('rapid_10_min_each')),
    ];
    try {
      final fetched = await repo.timeControlOptions();
      if (fetched.isNotEmpty) tcOptions = fetched;
    } catch (_) {
      // Creation still works with the default clock.
    }
    if (!context.mounted) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(trId('new_chess_tournament')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameC,
                  decoration: InputDecoration(labelText: trId('name'))),
              const SizedBox(height: 8),
              TextField(
                  controller: descC,
                  decoration:
                      InputDecoration(labelText: trId('description_2'))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: timeControl,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: trId('time_control')),
                items: [
                  for (final o in tcOptions)
                    DropdownMenuItem(
                        value: o.value,
                        child: Text(o.label,
                            style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setSt(() => timeControl = v ?? timeControl),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Text(
                    deadline == null
                        ? trId('registration_deadline_optional')
                        : DateFormat('d MMM y').format(deadline!),
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
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(trId('cancel_2'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(trId('create'))),
          ],
        ),
      ),
    );
    if (created == true && nameC.text.trim().isNotEmpty) {
      try {
        await repo.create(
          name: nameC.text.trim(),
          description: descC.text.trim(),
          registrationDeadline: deadline?.toUtc().toIso8601String(),
          timeControl: timeControl,
        );
        listBloc.load();
      } catch (_) {
        messenger.showSnackBar(SnackBar(
            content: Text(trId('could_not_create')),
            backgroundColor: AppColors.accent));
      }
    }
  }
}
