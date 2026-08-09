import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/services/siren_controller.dart';
import '../../domain/entities/safety_entities.dart' as e;
import '../bloc/sos_bloc.dart';
import 'sos_trigger_screen.dart' show kEmergencyNumber;

/// What the member sees after the SOS has gone.
///
/// This screen did not exist, and its absence is why the feature was worthless.
/// A member pressed a button, read "FYC members have been alerted" — which was
/// asserted after the server had merely *queued* a background task — and then
/// had nothing. No way to know whether anybody was coming, no way to say they
/// were safe.
///
/// The hardest line here is the honest one. Published response rates for
/// volunteer first responders run 17–47%, so *told, no answer yet* is the
/// ordinary case, and it is the line that makes somebody press Call 112. A
/// screen that hides it in a friendlier number is a screen that gets people
/// hurt.
class SosLiveScreen extends StatelessWidget {
  const SosLiveScreen({super.key});

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: BlocBuilder<SosBloc, SosViewState>(
          builder: (context, state) {
            final incident = state.incident;
            if (incident == null) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }
            return Column(
              children: [
                _Header(incident: incident),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      if (incident.isThrottled) _Notice(trId('throttled_notice')),
                      if (!incident.isOpen) _Notice(trId('stood_down')),
                      _Responders(incident: incident),
                      const SizedBox(height: 18),
                      _Contacts(incident: incident),
                      if (incident.isOpen) ...[
                        const SizedBox(height: 22),
                        _WhatIsIt(
                          chosen: incident.kind,
                          onChoose: (k) =>
                              context.read<SosBloc>().add(SosKindChosen(k)),
                        ),
                      ],
                    ],
                  ),
                ),
                _Actions(
                  incident: incident,
                  busy: state.busy,
                  onCall112: () => _dial(kEmergencyNumber),
                  onSafe: () =>
                      context.read<SosBloc>().add(const SosStoodDown()),
                  onReopen: () =>
                      context.read<SosBloc>().add(const SosReopened()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.incident});
  final e.SosIncident incident;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: incident.isOpen
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trId('sos_sent'),
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            formatAgo(incident.createdAt),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Who was told, and what each of them said.
class _Responders extends StatelessWidget {
  const _Responders({required this.incident});
  final e.SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final coming = incident.coming;
    final silent = incident.silentCount;

    if (incident.alertedCount == 0) {
      return _Notice(trId('nobody_yet'), hint: trId('nobody_yet_help'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in coming) _ResponderRow(responder: r),
        if (silent > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              // The honest line. Not folded into the alerted count, because
              // "six people know" and "nobody has answered" are both true and
              // only the second one changes what the member should do next.
              coming.isEmpty
                  ? trId('nobody_yet')
                  : trId('n_told_no_answer', {'n': silent}),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62), fontSize: 14),
            ),
          ),
        if (coming.isEmpty && silent > 0)
          Text(
            trId('nobody_yet_help'),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5),
          ),
        if (incident.isOpen &&
            coming.isEmpty &&
            incident.status == e.SosStatus.widening)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 10),
                Text(trId('widening_the_search'),
                    style: const TextStyle(
                        color: Color(0xFFF59E0B), fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResponderRow extends StatelessWidget {
  const _ResponderRow({required this.responder});
  final e.SosResponder responder;

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final distance = responder.distanceM;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_run_rounded,
              color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(responder.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(
                  [
                    if (distance != null) formatDistance(distance),
                    responder.hasArrived
                        ? trId('ive_arrived')
                        : trId('on_the_way'),
                  ].join(' · '),
                  style: const TextStyle(
                      color: Color(0xFF16A34A), fontSize: 13),
                ),
              ],
            ),
          ),
          if (responder.phone != null)
            IconButton(
              onPressed: () => _call(responder.phone!),
              tooltip: trId('call'),
              icon: const Icon(Icons.call_rounded, color: Color(0xFF16A34A)),
            ),
        ],
      ),
    );
  }
}

/// How long ago, without ever printing a negative number.
///
/// A device clock that is behind the server's makes `now - createdAt`
/// negative, and the first render of this screen said "raised -1102 min ago".
/// The elapsed time is decoration; the clock skew is not the member's problem.
String formatAgo(DateTime at) {
  final minutes = DateTime.now().difference(at).inMinutes;
  if (minutes < 1) return trId('just_now');
  return trId('raised_ago', {'n': minutes});
}

/// Metres up to a kilometre, then kilometres to one decimal.
///
/// "1400 m away" is a number somebody has to convert while frightened.
String formatDistance(int metres) => metres < 1000
    ? trId('m_away', {'n': metres})
    : trId('km_away', {'n': (metres / 1000).toStringAsFixed(1)});

class _Contacts extends StatelessWidget {
  const _Contacts({required this.incident});
  final e.SosIncident incident;

  @override
  Widget build(BuildContext context) {
    final sent = incident.contactsNotified;
    return Row(
      children: [
        Icon(
          sent > 0 ? Icons.mark_chat_read_rounded : Icons.sms_failed_rounded,
          size: 17,
          color: sent > 0 ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            // Counted, not claimed. If the deployment cannot send SMS this
            // says so, rather than leaving a member believing their family
            // has been told.
            sent > 0
                ? trId('sms_sent_to_contacts', {'n': sent})
                : trId('contacts_not_messaged'),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Asked after the alert has gone, never before.
class _WhatIsIt extends StatelessWidget {
  const _WhatIsIt({required this.chosen, required this.onChoose});

  final e.SosKind? chosen;
  final ValueChanged<e.SosKind> onChoose;

  static const _kinds = <(e.SosKind, String)>[
    (e.SosKind.medical, 'kind_medical'),
    (e.SosKind.threat, 'kind_threat'),
    (e.SosKind.accident, 'kind_accident'),
    (e.SosKind.fire, 'kind_fire'),
    (e.SosKind.other, 'kind_other'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(trId('what_happened'),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (kind, label) in _kinds)
              _DarkChip(
                label: trId(label),
                selected: chosen == kind,
                onTap: () => onChoose(kind),
              ),
          ],
        ),
      ],
    );
  }
}

/// A chip this screen owns, because the app's [ChipThemeData] is built for
/// light surfaces and put a white label on a pale background here.
class _DarkChip extends StatelessWidget {
  const _DarkChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFDC2626)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFFDC2626)
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.82),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.incident,
    required this.busy,
    required this.onCall112,
    required this.onSafe,
    required this.onReopen,
  });

  final e.SosIncident incident;
  final bool busy;
  final VoidCallback onCall112;
  final VoidCallback onSafe;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: onCall112,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.call_rounded),
                    label: Text(trId('call_112_now'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : (incident.isOpen ? onSafe : onReopen),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      incident.isOpen ? trId('im_safe') : trId('reopen_sos'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Off unless asked for, and it survives this screen closing.
          //
          // The alarm used to start by itself on this phone. It does not any
          // more — it is here for the one case where being heard is the point:
          // attracting a passer-by, or making somebody back off. The person
          // holding the phone is the only one who can judge that.
          ValueListenableBuilder<bool>(
            valueListenable: SirenController.instance.isPlaying,
            builder: (context, playing, _) => SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton.icon(
                onPressed: () => playing
                    ? SirenController.instance.stop()
                    : SirenController.instance.start(),
                style: TextButton.styleFrom(
                  foregroundColor:
                      playing ? const Color(0xFFF59E0B) : Colors.white60,
                ),
                icon: Icon(playing
                    ? Icons.volume_up_rounded
                    : Icons.campaign_outlined),
                label: Text(
                    playing ? trId('stop_alarm') : trId('sound_alarm_here')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 13)),
            ],
          ],
        ),
      );
}
