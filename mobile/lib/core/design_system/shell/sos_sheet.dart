import 'package:flutter/material.dart';
import '../../../core/l10n/tr.dart';

import '../../services/sos_service.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';

/// Shows the SOS action sheet: send a location SMS to trusted contacts and/or
/// dial the emergency number. Trusted contacts are stored on-device.
Future<void> showSosSheet(BuildContext context, {String? memberName}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SosSheet(memberName: memberName),
  );
}

class _SosSheet extends StatefulWidget {
  final String? memberName;
  const _SosSheet({this.memberName});

  @override
  State<_SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<_SosSheet> {
  List<String> _contacts = [];
  bool _loading = true;
  bool _busy = false;
  bool _sirenOn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Never leave the alarm blaring once the Safety Center is dismissed.
    SosService.stopSiren();
    super.dispose();
  }

  Future<void> _toggleAlarm() async {
    if (_sirenOn) {
      await SosService.stopSiren();
    } else {
      await SosService.startSiren();
    }
    if (mounted) setState(() => _sirenOn = SosService.isSirenPlaying);
  }

  Future<void> _load() async {
    final c = await SosService.getContacts();
    if (!mounted) return;
    setState(() {
      _contacts = c;
      _loading = false;
    });
  }

  Future<void> _alertMembers() async {
    setState(() => _busy = true);
    final pos = await SosService.currentLocation();
    SosService.startSiren();
    if (mounted) setState(() => _sirenOn = SosService.isSirenPlaying);
    final ok = await SosService.alertMembers(pos: pos);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(ok
        ? 'FYC members have been alerted.'
        : "Couldn't reach members — try SMS or call.");
  }

  Future<void> _sendSos() async {
    if (_contacts.isEmpty) {
      _snack('Add at least one trusted contact first.');
      return;
    }
    setState(() => _busy = true);
    final pos = await SosService.currentLocation();
    SosService.startSiren();
    if (mounted) setState(() => _sirenOn = SosService.isSirenPlaying);
    final msg = SosService.buildMessage(name: widget.memberName, pos: pos);
    final ok = await SosService.sendSms(_contacts, msg);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).maybePop();
      _snack('Opening SMS to your trusted contacts…');
    } else {
      _snack("Couldn't open the SMS app.");
    }
  }

  Future<void> _callEmergency() async {
    final ok = await SosService.callEmergency();
    if (!mounted) return;
    if (!ok) _snack("Couldn't open the dialer.");
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  List<Widget> _feature(IconData icon, String text) => [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Icon(icon, color: const Color(0xFF16A34A), size: 16),
            SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: TextStyle(color: Colors.white70, fontSize: 12.5))),
          ]),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF0B1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, color: Color(0xFFDC2626), size: 26),
                  SizedBox(width: 10),
                  Text(trId('safety_center'),
                      style: TextStyle(
                          color: AppColors.background,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
              Text(
                'Alert your trusted contacts and nearby FYC members, or call the '
                'emergency number.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 18),

              // Primary action — send SOS SMS.
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _busy ? null : _sendSos,
                  icon: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.background))
                      : Icon(Icons.send_rounded),
                  label: Text(_busy ? 'Getting location…' : 'Send SOS to my contacts'),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.background,
                    side: BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _callEmergency,
                  icon: Icon(Icons.call_rounded),
                  label: Text('Call ${SosService.emergencyNumber}'),
                ),
              ),
              SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.background,
                    side: BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _busy ? null : _alertMembers,
                  icon: Icon(Icons.campaign_rounded),
                  label: Text(trId('alert_nearby_fyc_members')),
                ),
              ),
              SizedBox(height: 10),

              // Loud alarm — a first-class control so the user can blare a
              // siren instantly (to attract attention / deter a threat) and
              // stop it. Turns amber and pulses while sounding.
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _sirenOn ? const Color(0xFFF59E0B) : AppColors.background,
                    backgroundColor: _sirenOn ? const Color(0x22F59E0B) : null,
                    side: BorderSide(color: _sirenOn ? const Color(0xFFF59E0B) : Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _toggleAlarm,
                  icon: Icon(_sirenOn ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                  label: Text(_sirenOn ? trId('stop_alarm') : trId('sound_loud_alarm')),
                ),
              ),

              SizedBox(height: 18),
              ..._feature(Icons.location_on_rounded, 'Share live location'),
              ..._feature(Icons.contacts_rounded, 'Alert trusted contacts'),
              ..._feature(Icons.groups_rounded, 'Notify nearby FYC members'),
              ..._feature(Icons.sms_rounded, 'Works offline (SMS fallback)'),

              ],
          ),
          ),
          ),
        ),
      ),
    );
  }
}
