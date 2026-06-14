import 'package:flutter/material';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BloodDonorsScreen extends StatefulWidget {
  const BloodDonorsScreen({super.key});

  @override
  State<BloodDonorsScreen> createState() => _BloodDonorsScreenState();
}

class _BloodDonorsScreenState extends State<BloodDonorsScreen> {
  String _selectedGroup = 'A+';
  List<dynamic> _donors = [];
  bool _loading = false;
  final String _apiBase = "http://10.0.2.2:8000/api/v1"; // Standard Android Emulator localhost mapping
  final String _orgId = "8f8b80b7-4b71-4770-b183-5c5f49e49a1d";

  @override
  void initState() {
    super.initState();
    _fetchDonors(_selectedGroup);
  }

  void _fetchDonors(String group) async {
    setState(() {
      _loading = true;
      _selectedGroup = group;
    });

    try {
      final response = await http.get(
        Uri.parse("$_apiBase/blood-donors?blood_group=${Uri.encodeComponent(group)}"),
        headers: {"X-Organization-ID": _orgId},
      );

      if (response.statusCode == 200) {
        setState(() {
          _donors = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // Mock fallback data for offline/unreachable backend
      setState(() {
        _donors = [
          {"id": "1", "full_name_ta": "கார்த்திக் ஜே", "full_name_en": "Karthik J", "blood_group": group, "is_available": true},
          {"id": "2", "full_name_ta": "மீனா ஆர்", "full_name_en": "Meena R", "blood_group": group, "is_available": true},
        ];
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('இரத்த தானம் / Blood Donors'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter Horizontal Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            color: Colors.red[50],
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: bloodGroups.length,
              itemBuilder: (context, index) {
                final group = bloodGroups[index];
                final active = _selectedGroup == group;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: ChoiceChip(
                    label: Text(group, style: TextStyle(fontWeight: FontWeight.bold, color: active ? Colors.white : Colors.black)),
                    selected: active,
                    selectedColor: Colors.red[900],
                    onSelected: (_) => _fetchDonors(group),
                  ),
                );
              },
            ),
          ),

          // Donors List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : _donors.isEmpty
                    ? const Center(child: Text('பட்டியல் காலியாக உள்ளது / No donors found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _donors.length,
                        itemBuilder: (context, index) {
                          final donor = _donors[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            child: ListTile(
                              title: Text(
                                donor['full_name_ta'] ?? donor['full_name_en'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: const Text('📍 Nagercoil'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.phone, color: Colors.green),
                                    onPressed: () {},
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
