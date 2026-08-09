import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/ds_screen_header.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/safety_entities.dart' as e;
import '../../domain/repositories/safety_repository.dart';
import 'sos_live_screen.dart' show formatAgo;

/// What is happening right now. Organisers only.
///
/// The board that could not exist while an SOS was a push and nothing else.
/// Its one unusual control is the stand-down, which requires ticking **I have
/// spoken to them** — an organiser deciding from a desk that somebody is
/// probably fine is exactly the inference this whole design forbids.
class LiveIncidentsScreen extends StatefulWidget {
  const LiveIncidentsScreen({super.key});

  @override
  State<LiveIncidentsScreen> createState() => _LiveIncidentsScreenState();
}

class _LiveIncidentsScreenState extends State<LiveIncidentsScreen> {
  final SafetyRepository _repo = sl<SafetyRepository>();

  List<e.SosSummary> _incidents = const [];
  bool _loading = true;
  String? _failure;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final live = await _repo.live();
      if (!mounted) return;
      setState(() {
        _incidents = live;
        _loading = false;
        _failure = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failure = err.toString();
      });
    }
  }

  Future<void> _standDown(e.SosSummary incident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _SpokeToThemDialog(name: incident.raisedByName),
    );
    if (confirmed != true) return;
    try {
      await _repo.standDown(incident.id,
          reason: 'Stood down by an organiser', spokeToThem: true);
    } catch (_) {
      // The list refreshes either way; a failed stand-down leaves the incident
      // open, which is the safe direction to fail in.
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DSScreenHeader(
        title: trId('live_incidents'),
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(DSSpacing.md),
                children: [
                  if (_failure != null)
                    Text(_failure!,
                        style: Theme.of(context).textTheme.bodySmall),
                  if (_incidents.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: DSSpacing.xl),
                      child: Center(
                        child: Text(trId('no_live_incidents'),
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ),
                  for (final incident in _incidents)
                    _IncidentRow(
                      incident: incident,
                      onOpen: () =>
                          context.push('/safety/respond/${incident.id}'),
                      onStandDown: () => _standDown(incident),
                    ),
                ],
              ),
            ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({
    required this.incident,
    required this.onOpen,
    required this.onStandDown,
  });

  final e.SosSummary incident;
  final VoidCallback onOpen;
  final VoidCallback onStandDown;

  @override
  Widget build(BuildContext context) {
    final coming = incident.acknowledgedCount;
    return Container(
      margin: EdgeInsets.only(bottom: DSSpacing.xs),
      padding: EdgeInsets.all(DSSpacing.sm),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DSRadius.card),
        border: Border.all(
          color: coming > 0 ? AppColors.success : AppColors.danger,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(incident.raisedByName,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              Text(formatAgo(incident.createdAt),
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          if ((incident.placeName ?? '').isNotEmpty)
            Text(incident.placeName!,
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            // The honest pair, side by side. "Six told" without "nobody
            // answered" is how a board makes a room feel covered when it is not.
            coming > 0
                ? '$coming ${trId('on_the_way')} · ${incident.alertedCount}'
                : trId('nobody_yet'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: coming > 0 ? AppColors.success : AppColors.danger,
                ),
          ),
          if (incident.isThrottled) ...[
            const SizedBox(height: 4),
            Text(trId('throttled_notice'),
                style: Theme.of(context).textTheme.labelSmall),
          ],
          SizedBox(height: DSSpacing.xs),
          Row(
            children: [
              OutlinedButton(onPressed: onOpen, child: Text(trId('sos'))),
              const Spacer(),
              TextButton(
                  onPressed: onStandDown, child: Text(trId('im_safe'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpokeToThemDialog extends StatefulWidget {
  const _SpokeToThemDialog({required this.name});
  final String name;

  @override
  State<_SpokeToThemDialog> createState() => _SpokeToThemDialogState();
}

class _SpokeToThemDialogState extends State<_SpokeToThemDialog> {
  bool _spoke = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trId('stand_down_confirm')),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _spoke,
            onChanged: (v) => setState(() => _spoke = v ?? false),
            title: Text(trId('i_have_spoken_to_them')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(trId('cancel_sos')),
        ),
        FilledButton(
          onPressed: _spoke ? () => Navigator.of(context).pop(true) : null,
          child: Text(trId('im_safe')),
        ),
      ],
    );
  }
}
