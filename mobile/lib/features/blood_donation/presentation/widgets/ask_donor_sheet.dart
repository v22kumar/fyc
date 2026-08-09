import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/location/member_location.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/blood_request_api.dart';
import '../../domain/entities/blood_donor_entity.dart';
import 'donor_presence.dart';

/// Ask one person, instead of being handed their phone number.
///
/// What this replaces: tapping a donor produced a confirmation dialog, then a
/// phone number, and then it was your problem. In an emergency that means
/// dialling strangers one after another and finding out — from the fourth one —
/// that the first three were unreachable, out of town, or gave blood last
/// month. The app knew all of that and made the person in trouble discover it
/// by phone.
///
/// The exchange here is the other way round. You ask. They answer. And **their
/// number arrives with the yes**, so the call you eventually make is to someone
/// expecting it. A declining donor's number is never disclosed — declining is a
/// real answer, and it stays private.
///
/// Two things are deliberate about the shape:
///
/// * **The ask is short.** Group and units are already known or default; the
///   hospital is one optional line. Someone standing at a counter is not going
///   to fill in a form, and every field is a chance to abandon it.
/// * **Calling is still there.** An async request that nobody answers cannot be
///   the only road out of an emergency, so the number is one clearly-labelled
///   tap away — described as what it is, a cold call.
Future<void> showAskDonorSheet(
  BuildContext context, {
  required BloodDonorEntity donor,
  required String lang,
  required VoidCallback onShowNumberInstead,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AskDonorSheet(
      donor: donor,
      lang: lang,
      onShowNumberInstead: onShowNumberInstead,
    ),
  );
}

class _AskDonorSheet extends StatefulWidget {
  const _AskDonorSheet({
    required this.donor,
    required this.lang,
    required this.onShowNumberInstead,
  });

  final BloodDonorEntity donor;
  final String lang;
  final VoidCallback onShowNumberInstead;

  @override
  State<_AskDonorSheet> createState() => _AskDonorSheetState();
}

class _AskDonorSheetState extends State<_AskDonorSheet> {
  final _hospital = TextEditingController();
  int _units = 1;
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _hospital.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      // Where the blood is needed, if we happen to know. Never asks for the
      // permission here — mid-request is the wrong moment to explain location.
      final pos = await MemberLocation.ifAlreadyAllowed();
      await BloodRequestApi.create(
        bloodGroup: widget.donor.bloodGroup,
        units: _units,
        hospital: _hospital.text.trim(),
        lat: pos?.latitude,
        lng: pos?.longitude,
        targetDonorId: widget.donor.id,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trId('request_failed'))),
      );
    }
  }

  /// The units stepper lives in [_Form], a separate widget; it changes state
  /// through this method rather than reaching into [setState] directly.
  void changeUnits(int delta) => setState(() => _units += delta);

  @override
  Widget build(BuildContext context) {
    final name = widget.donor.displayName(widget.lang);
    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        DSSpacing.lg,
        DSSpacing.lg,
        DSSpacing.lg,
        DSSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _sent ? _Sent(name: name) : _Form(state: this, name: name),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.state, required this.name});

  final _AskDonorSheetState state;
  final String name;

  @override
  Widget build(BuildContext context) {
    final donor = state.widget.donor;
    final presence = DonorPresence.of(donor.locationBasis);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Who, restated. The tap came off a list; naming the person makes the
        // ask feel like an ask rather than a form submission.
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: DSColors.danger.withValues(alpha: 0.10),
              child: Text(
                donor.bloodGroup,
                style: const TextStyle(
                  color: DSColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: DSSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  if (donor.distanceKm != null)
                    Row(
                      children: [
                        PresenceGlyph(presence, size: 12),
                        SizedBox(width: DSSpacing.xs),
                        Text(
                          presence.phrase(donor.distanceKm!),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: presence.color),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: DSSpacing.md),
        Text(
          trId('ask_donor_explainer'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: context.cTextSecondary),
        ),
        SizedBox(height: DSSpacing.md),
        Row(
          children: [
            Text(trId('units'),
                style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            IconButton(
              onPressed: state._units > 1 ? () => state.changeUnits(-1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('${state._units}',
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              onPressed: state._units < 10 ? () => state.changeUnits(1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        TextField(
          controller: state._hospital,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: trId('hospital_optional'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        SizedBox(height: DSSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: DSColors.danger),
            onPressed: state._sending ? null : state._send,
            icon: state._sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.volunteer_activism_rounded),
            label: Text(trId('ask_for_blood')),
          ),
        ),
        // Still a way out. An unanswered notification cannot be the only road
        // out of an emergency — but it is named honestly, so it is the second
        // choice rather than the reflex.
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              state.widget.onShowNumberInstead();
            },
            child: Text(trId('call_directly_instead')),
          ),
        ),
      ],
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_rounded, size: 36, color: AppColors.success),
        SizedBox(height: DSSpacing.sm),
        Text(
          trId('asked_name', {'name': name}),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: DSSpacing.xs),
        // Says what happens next, including the part that matters: the number
        // is coming, and it is coming with a yes.
        Text(
          trId('asked_what_happens_next'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: context.cTextSecondary),
        ),
        SizedBox(height: DSSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(trId('done')),
          ),
        ),
      ],
    );
  }
}

/// The number, once a donor has accepted — a warm call, not a cold one.
class AcceptedDonorSheet extends StatelessWidget {
  const AcceptedDonorSheet({
    super.key,
    required this.name,
    required this.phone,
  });

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(DSSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trId('accepted_your_request', {'name': name}),
                style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: DSSpacing.xs),
            SelectableText(phone,
                style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: DSSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                icon: const Icon(Icons.call_rounded),
                label: Text(trId('call')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
