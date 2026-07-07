import 'package:flutter/material.dart';
import '../../../../core/services/sos_service.dart';
import '../../../../core/theme/app_theme.dart';

class SafetySettingsScreen extends StatefulWidget {
  const SafetySettingsScreen({super.key});

  @override
  State<SafetySettingsScreen> createState() => _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends State<SafetySettingsScreen> {
  List<String> _contacts = [];
  bool _loudSiren = true;
  bool _loading = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        title: const Text('Safety Center'),
        backgroundColor: context.cBackground,
        foregroundColor: context.cText,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.cSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.cBorder),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _loudSiren,
                        activeColor: const Color(0xFFDC2626),
                        onChanged: (v) async {
                          await SosService.setLoudSiren(v);
                          if (mounted) setState(() => _loudSiren = v);
                        },
                        title: Text('Loud Siren',
                            style: TextStyle(fontWeight: FontWeight.w600, color: context.cText)),
                        subtitle: Text(
                            _loudSiren ? 'Vibrating alarm when you trigger SOS' : 'Silent mode',
                            style: TextStyle(color: context.cTextSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Trusted Contacts',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: context.cTextSecondary)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: context.cSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.cBorder),
                  ),
                  child: Column(
                    children: [
                      if (_contacts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('No contacts yet — add a phone number below.',
                              style: TextStyle(color: context.cTextSecondary, fontSize: 13)),
                        )
                      else
                        ..._contacts.map((c) => Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.person_rounded, color: AppColors.primary),
                                  title: Text(c, style: TextStyle(color: context.cText)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.red),
                                    onPressed: () => _removeContact(c),
                                  ),
                                ),
                                if (c != _contacts.last)
                                  Divider(height: 1, thickness: 1, color: context.cBorder, indent: 56),
                              ],
                            )),
                      Divider(height: 1, thickness: 1, color: context.cBorder),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _addCtrl,
                                keyboardType: TextInputType.phone,
                                style: TextStyle(color: context.cText),
                                decoration: InputDecoration(
                                  hintText: 'Add phone number',
                                  hintStyle: TextStyle(color: context.cTextSecondary),
                                  filled: true,
                                  fillColor: context.isDark ? Colors.white10 : Colors.black12,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _addContact,
                              icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF16A34A), size: 32),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
