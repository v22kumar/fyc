import 'package:flutter/material';

class IssueReportScreen extends StatefulWidget {
  const IssueReportScreen({super.key});

  @override
  State<IssueReportScreen> createState() => _IssueReportScreenState();
}

class _IssueReportScreenState extends State<IssueReportScreen> {
  String _selectedCategory = 'ROAD';
  final TextEditingController _descTaController = TextEditingController();
  final TextEditingController _descEnController = TextEditingController();
  String _geoText = 'இருப்பிடம் பெறப்படவில்லை / No location';
  bool _loading = false;

  void _getGeolocation() async {
    setState(() {
      _geoText = 'இருப்பிடம் பெறப்படுகிறது... / Locating...';
    });
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _geoText = 'Lat: 8.1833, Lng: 77.4119 (Nagercoil)';
    });
  }

  void _submitIssue() async {
    setState(() {
      _loading = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _loading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('புகார் பதிவு செய்யப்பட்டது! / Issue Reported!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('புகார் செய்க / Report Issue'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category Dropdown
              const Text('பிரச்சனை வகை / Category', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'ROAD', child: Text('சாலை பிரச்சனைகள் / Road Issues')),
                  DropdownMenuItem(value: 'WATER', child: Text('குடிநீர் விநியோகம் / Water Issues')),
                  DropdownMenuItem(value: 'STREET_LIGHT', child: Text('தெரு விளக்கு பழுது / Street Light')),
                  DropdownMenuItem(value: 'GARBAGE', child: Text('கழிவு மேலாண்மை / Garbage')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Description Tamil
              const Text('விளக்கம் (தமிழ்) / Description (Tamil)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _descTaController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'பிரச்சனையை விளக்கவும்...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),

              // Description English
              const Text('Description (English)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _descEnController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe the issue...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),

              // Geolocation
              const Text('இருப்பிடம் / Geolocation', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _getGeolocation,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Get Geolocation'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_geoText, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF064E3B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _loading ? null : _submitIssue,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('பதிவு செய்க / Submit Issue', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
