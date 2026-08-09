import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/services/siren_controller.dart';
import '../bloc/sos_bloc.dart';
import '../widgets/hold_ring.dart';

/// India's single emergency number — police, fire and ambulance.
const kEmergencyNumber = '112';

/// The one screen a frightened member sees, with one thing on it.
///
/// What this replaces was a bottom sheet with four buttons of near-identical
/// weight — send SMS, call 112, alert members, sound alarm — under a list of
/// four green ticks that were static text rather than state, one of which
/// ("Works offline") was simply untrue.
///
/// An emergency does not want a menu. It wants **one committed act with a way
/// to take it back**: hold for three seconds, then five seconds of countdown
/// with CANCEL filling the screen. That is what Apple, Android and Tamil Nadu's
/// own Kavalan SOS all do, and the cancel is the point — it is what makes a
/// false alarm cheap, and only a cheap false alarm can justify a hair-trigger
/// like shake-to-open.
///
/// The three lines at the bottom replace the green ticks. They are read from
/// actual state, and each one is a link to fix itself when it reads badly.
class SosTriggerScreen extends StatefulWidget {
  const SosTriggerScreen({super.key, this.rehearsal = false});

  /// A dry run from the setup screen. Everything behaves identically and
  /// nothing is sent — because nobody should press this button for the first
  /// time in an emergency and discover then that they have no contacts.
  final bool rehearsal;

  @override
  State<SosTriggerScreen> createState() => _SosTriggerScreenState();
}

class _SosTriggerScreenState extends State<SosTriggerScreen> {
  static const _countdown = 5;

  Timer? _ticker;
  int _remaining = 0;

  bool get _counting => _ticker != null;

  @override
  void initState() {
    super.initState();
    context.read<SosBloc>().add(const ReadinessRequested());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Deliberately does NOT stop the siren. That was the old bug: the alarm
    // lived inside a sheet and died with it, so dismissing the screen — or
    // having the phone taken — silenced it.
    super.dispose();
  }

  void _beginCountdown() {
    if (_counting) return;
    // No siren here, on purpose.
    //
    // It used to start the moment the button was held, on the phone of the
    // person in trouble — which is the one phone it must not sound on. In a
    // threat it announces to the person you are afraid of that you have called
    // for help; during a 112 call it drowns out the call; and it is frightening
    // at the moment somebody least needs that. The alarm belongs on the phone
    // of somebody who can come, and that is where it now goes.
    //
    // It is still one tap away on the live screen, for the case where being
    // heard is the point.
    setState(() => _remaining = _countdown);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining > 0) {
        HapticFeedback.selectionClick();
        return;
      }
      _ticker?.cancel();
      _ticker = null;
      _send();
    });
  }

  void _cancel() {
    _ticker?.cancel();
    _ticker = null;
    // Defensive: nothing here starts the siren any more, but a member who
    // turned it on by hand and then cancelled should not be left with it
    // blaring at a false alarm.
    SirenController.instance.stop();
    HapticFeedback.mediumImpact();
    setState(() => _remaining = 0);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(trId('sos_cancelled'))));
  }

  void _send() {
    if (widget.rehearsal) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(trId('rehearse_done'))));
      Navigator.of(context).maybePop();
      return;
    }
    context.read<SosBloc>().add(const SosRaised());
  }

  Future<void> _call112() async {
    final uri = Uri(scheme: 'tel', path: kEmergencyNumber);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // The dialler refusing to open is not something this screen can fix, and
      // an error toast in front of somebody in trouble helps nobody.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SosBloc, SosViewState>(
      listenWhen: (a, b) =>
          (!a.wentOffline && b.wentOffline) ||
          (a.failure != b.failure && b.failure != null),
      listener: (context, state) {
        if (state.wentOffline) {
          // The degradation ladder working, not a failure the member has to
          // act on — so it gets its own sentence rather than a red toast. And
          // it says what actually happened: the composer is open and they
          // still have to press send. "Works offline" was the old claim, and
          // it was never true.
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text('${trId('no_network_sms_opened')} '
                  '${trId('queued_will_send')}'),
              duration: const Duration(seconds: 8),
            ));
          return;
        }
        // Nothing here navigates. [SosScreen] swaps to the live screen when
        // an incident appears, because pushing a route put that screen
        // outside the BlocProvider it depends on — and disposed the bloc on
        // the way. See the note on SosScreen.
        if (state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.failure!),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 6),
            ));
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF0B1220),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        widget.rehearsal ? trId('rehearse') : trId('sos'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          _ticker?.cancel();
                          Navigator.of(context).maybePop();
                        },
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white54),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: _counting
                          ? _Countdown(remaining: _remaining, onCancel: _cancel)
                          : HoldRing(
                              label: trId('hold_to_send'),
                              hint: trId('hold_three_seconds'),
                              onComplete: _beginCountdown,
                            ),
                    ),
                  ),
                  if (!_counting) ...[
                    // Present whatever else is true, and never gated on login,
                    // network or setup. The one thing this screen must always
                    // be able to do is be a faster dialler than the dialler.
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _call112,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.call_rounded),
                        label: Text(trId('call_112_now'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Readiness(
                      readiness: state.readiness,
                      onFixContacts: () => context.push('/settings/safety'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Five seconds, and a cancel that is the biggest thing on the screen.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.remaining, required this.onCancel});

  final int remaining;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$remaining',
          style: const TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 120,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          trId('sending_in', {'n': remaining}),
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8), fontSize: 15),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: 240,
          height: 68,
          child: FilledButton(
            onPressed: onCancel,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0B1220),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              trId('cancel_sos'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

/// What this screen can honestly promise, before anything is pressed.
///
/// The four green ticks it replaces — *Share live location · Alert trusted
/// contacts · Notify nearby FYC members · Works offline (SMS fallback)* — were
/// static decoration on a safety screen, and the last was false. These three
/// lines are read from state, and a line that reads badly is a link to fix it.
class _Readiness extends StatelessWidget {
  const _Readiness({required this.readiness, required this.onFixContacts});

  final SosReadiness readiness;
  final VoidCallback onFixContacts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(
          context,
          icon: readiness.hasLocation
              ? Icons.location_on_rounded
              : Icons.location_off_rounded,
          ok: readiness.hasLocation,
          text: readiness.locating
              ? trId('getting_your_location')
              : readiness.hasLocation
                  ? [
                      readiness.place,
                      trId('accurate_to', {'n': readiness.accuracyM!.round()}),
                    ].whereType<String>().join(' · ')
                  : trId('location_unknown'),
          hint: (!readiness.locating && !readiness.hasLocation)
              ? trId('location_unknown_help')
              : null,
        ),
        _line(
          context,
          icon: Icons.contacts_rounded,
          ok: readiness.contacts > 0,
          text: switch (readiness.contacts) {
            0 => trId('no_trusted_contacts'),
            1 => trId('one_trusted_contact'),
            _ => trId('n_trusted_contacts', {'n': readiness.contacts}),
          },
          action: readiness.contacts == 0 ? trId('add_one_now') : null,
          onAction: onFixContacts,
        ),
      ],
    );
  }

  Widget _line(
    BuildContext context, {
    required IconData icon,
    required bool ok,
    required String text,
    String? hint,
    String? action,
    VoidCallback? onAction,
  }) {
    final tint = ok ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13.5)),
                if (hint != null)
                  Text(hint,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12)),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  visualDensity: VisualDensity.compact),
              child: Text(action),
            ),
        ],
      ),
    );
  }
}
