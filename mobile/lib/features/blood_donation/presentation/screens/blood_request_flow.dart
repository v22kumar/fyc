import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/location/member_location.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/blood_request_api.dart';
import '../../data/blood_request_models.dart';

const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const _urgencies = ['CRITICAL', 'URGENT', 'ROUTINE'];

/// Best-effort current location (never throws) — the request still goes out
/// without coordinates, just without proximity fan-out.
///
/// Deliberately the non-asking variant. Someone raising a blood request has
/// already tapped submit; a permission sheet at that moment reads as an
/// obstacle between them and help, and a sheet answered in a panic is not
/// consent. If they have already agreed elsewhere, we use it.
Future<Position?> _currentLocation() => MemberLocation.ifAlreadyAllowed();

Future<void> showRaiseRequestSheet(BuildContext context, {String? initialGroup}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RaiseRequestSheet(initialGroup: initialGroup),
  );
}

class _RaiseRequestSheet extends StatefulWidget {
  final String? initialGroup;
  const _RaiseRequestSheet({this.initialGroup});
  @override
  State<_RaiseRequestSheet> createState() => _RaiseRequestSheetState();
}

class _RaiseRequestSheetState extends State<_RaiseRequestSheet> {
  late String _group = widget.initialGroup ?? 'O+';
  String _urgency = 'URGENT';
  int _units = 1;
  final _hospitalCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _hospitalCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final pos = await _currentLocation();
      final req = await BloodRequestApi.create(
        bloodGroup: _group,
        units: _units,
        hospital: _hospitalCtrl.text.trim(),
        lat: pos?.latitude,
        lng: pos?.longitude,
        urgency: _urgency,
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BloodRequestScreen(requestId: req.id),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(trId('couldn_t_raise_request')),
          backgroundColor: AppColors.accent,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.emergency_rounded, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text(trId('request_blood'),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: context.cText)),
                ]),
                SizedBox(height: 16),
                Text(trId('patient_blood_group'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.cText, fontSize: 13)),
                SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final g in _groups)
                    ChoiceChip(
                      label: Text(g),
                      selected: _group == g,
                      selectedColor: AppColors.danger,
                      labelStyle: TextStyle(
                          color: _group == g ? AppColors.background : context.cText,
                          fontWeight: FontWeight.w700),
                      onSelected: (_) => setState(() => _group = g),
                    ),
                ]),
                SizedBox(height: 16),
                Text(trId('urgency'),
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.cText, fontSize: 13)),
                SizedBox(height: 8),
                Row(children: [
                  for (final u in _urgencies)
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(trId('urgency_${u.toLowerCase()}')),
                        selected: _urgency == u,
                        selectedColor: u == 'CRITICAL' ? AppColors.danger : AppColors.primary,
                        labelStyle: TextStyle(
                            color: _urgency == u ? AppColors.background : context.cText,
                            fontWeight: FontWeight.w600),
                        onSelected: (_) => setState(() => _urgency = u),
                      ),
                    ),
                ]),
                SizedBox(height: 16),
                TextField(
                  controller: _hospitalCtrl,
                  decoration: InputDecoration(
                    labelText: trId('hospital_optional'),
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                  ),
                ),
                SizedBox(height: 12),
                Row(children: [
                  Text('${trId('units')}: ', style: TextStyle(color: context.cText, fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: () => setState(() => _units = (_units - 1).clamp(1, 20)),
                    icon: Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_units', style: TextStyle(color: context.cText, fontWeight: FontWeight.w800, fontSize: 16)),
                  IconButton(
                    onPressed: () => setState(() => _units = (_units + 1).clamp(1, 20)),
                    icon: Icon(Icons.add_circle_outline),
                  ),
                ]),
                SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.info_outline, size: 14, color: context.cTextSecondary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(trId('nearby_donors_will_be_alerted'),
                        style: TextStyle(fontSize: 11.5, color: context.cTextSecondary)),
                  ),
                ]),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                        : Icon(Icons.campaign_rounded),
                    label: Text(_busy ? trId('sending') : trId('send_request')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Responders screen ────────────────────────────────────────────────────────
class BloodRequestScreen extends StatefulWidget {
  final String requestId;
  const BloodRequestScreen({super.key, required this.requestId});
  @override
  State<BloodRequestScreen> createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends State<BloodRequestScreen> {
  BloodRequest? _req;
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await BloodRequestApi.detail(widget.requestId);
      if (mounted) setState(() { _req = r; _error = false; });
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(trId('action_failed_try_again')), backgroundColor: AppColors.accent));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = _req;
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(title: Text(trId('blood_request'))),
      body: r == null && !_error
          ? Center(child: CircularProgressIndicator())
          : _error
              ? Center(child: ElevatedButton(onPressed: _load, child: Text(trId('retry_2'))))
              : RefreshIndicator(onRefresh: _load, child: _body(r!)),
    );
  }

  Widget _body(BloodRequest r) {
    final children = <Widget>[
      // Header card
      Container(
        margin: EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.danger, const Color(0xFFF87171)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Container(
            width: 54, height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: Text(r.patientBloodGroup,
                style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.unitsNeeded} ${trId('units')} · ${trId('urgency_${r.urgency.toLowerCase()}')}',
                  style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w800, fontSize: 15)),
              if (r.hospitalName != null && r.hospitalName!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(r.hospitalName!, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5)),
                ),
              SizedBox(height: 4),
              Text(r.isOpen ? trId('open') : trId('completed'),
                  style: TextStyle(color: AppColors.background, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
      // Stats
      Row(children: [
        Expanded(child: _stat('${r.notifiedCount}', trId('donors_notified'))),
        SizedBox(width: 10),
        Expanded(child: _stat('${r.acceptedCount}', trId('responding'), color: const Color(0xFF16A34A))),
      ]),
      SizedBox(height: 16),
    ];

    // Donor pledge action (accept / decline) — for donors, when open.
    if (r.isOpen) {
      children.add(_pledgeBar(r));
      children.add(SizedBox(height: 16));
    }

    // Responders list
    children.add(Text(trId('responders'),
        style: TextStyle(fontWeight: FontWeight.w800, color: context.cText, fontSize: 15)));
    children.add(SizedBox(height: 8));
    final accepted = r.pledges.where((p) => p.status == 'ACCEPTED').toList();
    if (accepted.isEmpty) {
      children.add(Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(trId('no_responders_yet'), style: TextStyle(color: context.cTextSecondary)),
      ));
    } else {
      for (final p in accepted) {
        children.add(Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.cBorder),
          ),
          // The payoff of asking instead of calling: their number arrives with
          // the yes. The server sends it only to the requester and only for
          // donors who accepted, so a row without one is somebody else's view
          // of this request, not a missing feature.
          child: Row(children: [
            Icon(Icons.volunteer_activism_rounded, color: const Color(0xFF16A34A), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.donorName ?? trId('a_donor'),
                      style: TextStyle(color: context.cText, fontWeight: FontWeight.w600)),
                  if (p.donorPhone != null)
                    Text(p.donorPhone!,
                        style: TextStyle(color: context.cTextSecondary, fontSize: 13)),
                ],
              ),
            ),
            if (p.donorPhone != null)
              IconButton(
                tooltip: trId('call'),
                icon: Icon(Icons.call_rounded, color: const Color(0xFF16A34A)),
                onPressed: () => launchUrl(Uri.parse('tel:${p.donorPhone}')),
              ),
          ]),
        ));
      }
    }

    // Requester controls
    if (r.isOpen) {
      children.add(SizedBox(height: 12));
      if (r.contactPhone != null && r.contactPhone!.isNotEmpty)
        children.add(SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _call(r.contactPhone!),
            icon: Icon(Icons.call),
            label: Text(trId('call_requester')),
          ),
        ));
      children.add(SizedBox(height: 8));
      children.add(SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: _busy ? null : () => _run(() => BloodRequestApi.close(r.id).then((_) {})),
          icon: Icon(Icons.check_circle_outline),
          label: Text(trId('mark_fulfilled')),
        ),
      ));
    }

    return ListView(padding: EdgeInsets.all(16), children: children);
  }

  Widget _stat(String value, String label, {Color? color}) => Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cBorder),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: color ?? context.cText)),
          SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: context.cTextSecondary)),
        ]),
      );

  Widget _pledgeBar(BloodRequest r) {
    if (r.myPledge == 'ACCEPTED') {
      return Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x2216A34A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF16A34A)),
        ),
        child: Row(children: [
          Icon(Icons.check_circle, color: Color(0xFF16A34A)),
          SizedBox(width: 10),
          Expanded(child: Text(trId('you_accepted_thank_you'),
              style: TextStyle(color: context.cText, fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: _busy ? null : () => _run(() => BloodRequestApi.pledge(r.id, 'DECLINED').then((_) {})),
            child: Text(trId('cancel_2')),
          ),
        ]),
      );
    }
    // Stacked, not side by side.
    //
    // Two reasons. The decline button used to sit in a Row unflexed, which made
    // the row ask it for an intrinsic width and took the whole screen down —
    // "BoxConstraints forces an infinite width", and a member who raised a
    // request got a blank page under the app bar. Nobody had ever opened this
    // screen on a device, so nobody had seen it.
    //
    // And side by side, "I can help" in Tamil left the decline button clipped
    // to "முடியா…". Full width each cannot clip in any language, and it puts
    // the accept where a primary action belongs.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              padding: EdgeInsets.symmetric(vertical: 14)),
          onPressed: _busy ? null : () => _run(() => BloodRequestApi.pledge(r.id, 'ACCEPTED').then((_) {})),
          icon: Icon(Icons.volunteer_activism_rounded),
          label: Text(trId('i_can_help')),
        ),
        TextButton(
          onPressed: _busy ? null : () => _run(() => BloodRequestApi.pledge(r.id, 'DECLINED').then((_) {})),
          child: Text(trId('decline')),
        ),
      ],
    );
  }
}
