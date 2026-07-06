import 'package:flutter/material.dart';

import '../../services/sos_service.dart';

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
  bool _loudSiren = true;
  bool _loading = true;
  bool _busy = false;
  final _addCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await SosService.getContacts();
    final siren = await SosService.getLoudSiren();
    if (!mounted) return;
    setState(() {
      _contacts = c;
      _loudSiren = siren;
      _loading = false;
    });
  }

  Future<void> _alertMembers() async {
    setState(() => _busy = true);
    final pos = await SosService.currentLocation();
    SosService.triggerSiren();
    final ok = await SosService.alertMembers(pos: pos);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(ok
        ? 'FYC members have been alerted.'
        : "Couldn't reach members — try SMS or call.");
  }

  Future<void> _addContact() async {
    final n = _addCtrl.text.trim();
    if (n.isEmpty) return;
    final next = [..._contacts, n];
    await SosService.saveContacts(next);
    _addCtrl.clear();
    if (!mounted) return;
    setState(() => _contacts = next);
  }

  Future<void> _removeContact(String n) async {
    final next = _contacts.where((c) => c != n).toList();
    await SosService.saveContacts(next);
    if (!mounted) return;
    setState(() => _contacts = next);
  }

  Future<void> _sendSos() async {
    if (_contacts.isEmpty) {
      _snack('Add at least one trusted contact first.');
      return;
    }
    setState(() => _busy = true);
    final pos = await SosService.currentLocation();
    SosService.triggerSiren();
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
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Icon(icon, color: const Color(0xFF16A34A), size: 16),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
          ]),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B1220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.health_and_safety_rounded, color: Color(0xFFDC2626), size: 26),
                  const SizedBox(width: 10),
                  const Text('Safety Center',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  ),
                ],
              ),
              const Text(
                'Alert your trusted contacts and nearby FYC members, or call the '
                'emergency number.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 18),

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
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(_busy ? 'Getting location…' : 'Send SOS to my contacts'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _callEmergency,
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Call ${SosService.emergencyNumber}'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _busy ? null : _alertMembers,
                  icon: const Icon(Icons.campaign_rounded),
                  label: const Text('Alert nearby FYC members'),
                ),
              ),

              const SizedBox(height: 18),
              ..._feature(Icons.location_on_rounded, 'Share live location'),
              ..._feature(Icons.contacts_rounded, 'Alert trusted contacts'),
              ..._feature(Icons.groups_rounded, 'Notify nearby FYC members'),
              ..._feature(Icons.sms_rounded, 'Works offline (SMS fallback)'),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _loudSiren,
                activeColor: const Color(0xFFDC2626),
                onChanged: (v) async {
                  await SosService.setLoudSiren(v);
                  if (mounted) setState(() => _loudSiren = v);
                },
                title: const Text('Loud Siren',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(
                    _loudSiren ? 'Vibrating alarm when you trigger SOS' : 'Silent mode',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),

              const SizedBox(height: 8),
              const Text('Trusted contacts',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Loading…', style: TextStyle(color: Colors.white54)),
                )
              else if (_contacts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('No contacts yet — add a phone number below.',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                )
              else
                ..._contacts.map((c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.person_rounded,
                          color: Colors.white70, size: 20),
                      title: Text(c,
                          style: const TextStyle(color: Colors.white)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white38, size: 20),
                        onPressed: () => _removeContact(c),
                      ),
                    )),

              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add phone number',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addContact,
                    icon: const Icon(Icons.add_circle_rounded,
                        color: Color(0xFF16A34A), size: 32),
                  ),
                ],
              ),
            ],
          ),
          ),
          ),
        ),
      ),
    );
  }
}
