import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../bloc/issue_bloc.dart';
import '../bloc/issue_event.dart';
import '../bloc/issue_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../service_locator.dart';

class SubmitIssueScreen extends StatefulWidget {
  const SubmitIssueScreen({super.key});

  @override
  State<SubmitIssueScreen> createState() => _SubmitIssueScreenState();
}

class _SubmitIssueScreenState extends State<SubmitIssueScreen> {
  static const _categories = [
    ('ROAD',         '🛣️',  'சாலை பிரச்சனை',    'Road Issue'),
    ('WATER',        '💧',  'தண்ணீர் பிரச்சனை',  'Water Issue'),
    ('STREET_LIGHT', '💡',  'தெரு விளக்கு',       'Street Light'),
    ('GARBAGE',      '🗑️', 'குப்பை',            'Garbage'),
    ('SAFETY',       '🚨',  'பாதுகாப்பு',          'Safety'),
    ('OTHER',        '📋',  'மற்றவை',            'Other'),
  ];

  String _selectedCategory = 'ROAD';
  final _descTaCtrl = TextEditingController();
  final _descEnCtrl = TextEditingController();
  double _lat = 8.1833;
  double _lng = 77.4119;
  Uint8List? _photo;
  String? _uploadedPhotoUrl;
  bool _uploading = false;

  String get _lang => sl<LocalStorage>().getLang();

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (picked == null) return;
    // Read bytes so the same path works on web and native (dart:io File is
    // unavailable on web).
    final bytes = await picked.readAsBytes();
    setState(() { _photo = bytes; _uploading = true; });
    try {
      final client = sl<ApiClient>();
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'issue.jpg'),
      });
      final resp = await client.dio.post('/api/v1/media/upload', data: form);
      setState(() { _uploadedPhotoUrl = resp.data['url'] as String?; });
    } catch (_) {
      // Photo upload failed — submission will proceed without it
      setState(() { _photo = null; });
    } finally {
      setState(() { _uploading = false; });
    }
  }

  @override
  void dispose() {
    _descTaCtrl.dispose();
    _descEnCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<IssueBloc>().add(
          IssueSubmitRequested(
            category: _selectedCategory,
            descriptionTa: _descTaCtrl.text,
            descriptionEn: _descEnCtrl.text,
            latitude: _lat,
            longitude: _lng,
            photoUrl: _uploadedPhotoUrl,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isTa = _lang == 'ta';
    return Scaffold(
      appBar: AppBar(
        title: Text(isTa ? 'பிரச்சனை தெரிவிக்கவும்' : 'Report an Issue'),
      ),
      body: BlocListener<IssueBloc, IssueState>(
        listener: (context, state) {
          if (state is IssueSubmitSuccess) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                title: Text(isTa ? 'வெற்றி!' : 'Submitted!'),
                content: Text(
                  isTa
                      ? 'உங்கள் புகார் #${state.issue.id.substring(0, 8)} பதிவாகியுள்ளது.'
                      : 'Your issue #${state.issue.id.substring(0, 8)} has been logged.',
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.pop();
                    },
                    child: Text(isTa ? 'சரி' : 'OK'),
                  ),
                ],
              ),
            );
          }
          if (state is IssueFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.accent,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoBanner(isTa: isTa),
              const SizedBox(height: 20),
              Text(
                isTa ? 'வகை தேர்வு செய்யவும்' : 'Select Category',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _CategoryGrid(
                categories: _categories,
                selected: _selectedCategory,
                lang: _lang,
                onSelect: (c) => setState(() => _selectedCategory = c),
              ),
              const SizedBox(height: 20),
              Text(
                isTa ? 'தமிழில் விவரம்' : 'Description (Tamil)',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descTaCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'இங்கே தமிழில் எழுதுங்கள்...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isTa ? 'ஆங்கிலத்தில் விவரம்' : 'Description (English)',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descEnCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe the issue in English...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isTa ? 'புகைப்படம் (விரும்பினால்)' : 'Photo (optional)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _PhotoPicker(
                photo: _photo,
                uploading: _uploading,
                onPick: _pickPhoto,
              ),
              const SizedBox(height: 16),
              _LocationRow(lat: _lat, lng: _lng),
              const SizedBox(height: 28),
              BlocBuilder<IssueBloc, IssueState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: state is IssueLoading ? null : _submit,
                      child: state is IssueLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isTa ? 'புகார் அனுப்பவும்' : 'Submit Issue',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final bool isTa;
  const _InfoBanner({required this.isTa});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isTa
                  ? 'உங்கள் புகார் நம் நிர்வாக குழுவிடம் சென்று தகுந்த நடவடிக்கை எடுக்கப்படும்.'
                  : 'Your report will be reviewed by our team and necessary action will be taken.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<(String, String, String, String)> categories;
  final String selected;
  final String lang;
  final void Function(String) onSelect;

  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.lang,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: categories.map((cat) {
        final isSelected = cat.$1 == selected;
        return GestureDetector(
          onTap: () => onSelect(cat.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.12)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(cat.$2, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  lang == 'ta' ? cat.$3 : cat.$4,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.primary : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final Uint8List? photo;
  final bool uploading;
  final VoidCallback onPick;

  const _PhotoPicker({
    required this.photo,
    required this.uploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onPick,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photo != null ? AppColors.primary : Colors.grey[300]!,
            style: photo != null ? BorderStyle.solid : BorderStyle.solid,
          ),
          color: Colors.grey[50],
        ),
        child: uploading
            ? const Center(child: CircularProgressIndicator())
            : photo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(photo!, fit: BoxFit.cover, width: double.infinity),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.camera_alt, color: Colors.grey, size: 32),
                      SizedBox(height: 6),
                      Text('Tap to take photo', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final double lat;
  final double lng;
  const _LocationRow({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('GPS', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
