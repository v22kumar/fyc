import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/tr.dart';
import '../../domain/entities/safety_entities.dart' as e;
import '../bloc/responder_bloc.dart';
import 'sos_live_screen.dart' show formatAgo, formatDistance;

/// Somebody near you needs help.
///
/// Full screen, opened straight from the push, because a notification row is
/// where this used to end: the old broadcast pushed a maps link to the whole
/// club and there was nothing on the other side of the tap. Nobody could
/// answer it, so nobody did.
///
/// Three facts and two buttons. **I'm coming** and **Can't** are equal in
/// weight on purpose: published response rates run 17–47%, so most taps here
/// will be the second one — and a decline is genuinely useful, because once a
/// whole wave has declined the ring widens immediately instead of waiting out
/// the timer. A screen that shames the "no" gets neither answer.
class ResponderAlertScreen extends StatefulWidget {
  const ResponderAlertScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  State<ResponderAlertScreen> createState() => _ResponderAlertScreenState();
}

class _ResponderAlertScreenState extends State<ResponderAlertScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ResponderBloc>().add(AlertOpened(widget.incidentId));
  }

  Future<void> _open(Uri uri) async {
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
        child: BlocConsumer<ResponderBloc, ResponderViewState>(
          listenWhen: (a, b) => a.failure != b.failure && b.failure != null,
          listener: (context, state) => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.failure!),
              backgroundColor: const Color(0xFFDC2626),
            )),
          builder: (context, state) {
            if (state.loading || state.alert == null) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }
            final alert = state.alert!;
            final over = alert.status == e.SosStatus.stoodDown;

            return Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white54),
                    ),
                  ),
                  const Spacer(),
                  const Text('🆘', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 14),
                  Text(
                    trId('needs_help', {'name': alert.raisedByName}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // The two things that decide whether somebody goes, said
                  // plainly. Neither survives being buried in a push body.
                  Text(
                    [
                      alert.distanceM != null
                          ? formatDistance(alert.distanceM!)
                          : trId('distance_unknown'),
                      if ((alert.placeName ?? '').isNotEmpty) alert.placeName!,
                      formatAgo(alert.raisedAt),
                    ].join(' · '),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 15),
                  ),
                  const Spacer(),
                  if (over)
                    _Said(trId('sos_already_over'))
                  else if (!alert.answered)
                    _Choice(
                      busy: state.busy,
                      onComing: () =>
                          context.read<ResponderBloc>().add(const Accepted()),
                      onCant: () =>
                          context.read<ResponderBloc>().add(const Declined()),
                    )
                  else if (alert.isComing)
                    _Coming(
                      alert: alert,
                      busy: state.busy,
                      onNavigate: alert.hasLocation
                          ? () => _open(Uri.parse(
                              'https://www.google.com/maps/dir/?api=1&destination='
                              '${alert.latitude},${alert.longitude}'))
                          : null,
                      onCall: alert.raiserPhone != null
                          ? () => _open(
                              Uri(scheme: 'tel', path: alert.raiserPhone))
                          : null,
                      onArrived: () =>
                          context.read<ResponderBloc>().add(const Arrived()),
                    )
                  else
                    _Said(trId('you_said_you_cant'),
                        hint: trId('thanks_for_saying')),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.busy, required this.onComing, required this.onCant});

  final bool busy;
  final VoidCallback onComing;
  final VoidCallback onCant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 62,
            child: FilledButton(
              onPressed: busy ? null : onComing,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(trId('im_coming'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 62,
            child: OutlinedButton(
              onPressed: busy ? null : onCant,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(trId('i_cant'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Coming extends StatelessWidget {
  const _Coming({
    required this.alert,
    required this.busy,
    required this.onNavigate,
    required this.onCall,
    required this.onArrived,
  });

  final e.ResponderAlert alert;
  final bool busy;
  final VoidCallback? onNavigate;
  final VoidCallback? onCall;
  final VoidCallback onArrived;

  @override
  Widget build(BuildContext context) {
    final arrived = alert.myArrivedAt != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Said(trId('you_said_you_are_coming')),
        const SizedBox(height: 12),
        Row(
          children: [
            if (onNavigate != null)
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: onNavigate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: Text(trId('navigate')),
                  ),
                ),
              ),
            if (onNavigate != null && onCall != null) const SizedBox(width: 10),
            if (onCall != null)
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(trId('call_them',
                        {'name': alert.raisedByName.split(' ').first})),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: (busy || arrived) ? null : onArrived,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(trId('ive_arrived'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class _Said extends StatelessWidget {
  const _Said(this.text, {this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: 13.5)),
            ],
          ],
        ),
      );
}
