import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../bloc/issue_bloc.dart';
import '../bloc/issue_event.dart';
import '../bloc/issue_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

// ── Category definitions ──────────────────────────────────────────────────────

class _Cat {
  final String id, labelTa, labelEn, subtitleEn;
  final IconData icon;
  final Color color;
  const _Cat(this.id, this.icon, this.labelTa, this.labelEn, this.subtitleEn, this.color);
}

const _categories = [
  _Cat('ROAD_TRAFFIC', Icons.add_road_rounded, 'சாலை / போக்குவரத்து', 'Road/Traffic', 'Potholes, Blockages, etc.', Color(0xFF16A34A)),
  _Cat('POWER_CUT',    Icons.bolt_rounded,     'மின் தடை',          'Power Cut',    'Outages, Broken wires',    Color(0xFFD97706)),
  _Cat('WATER',        Icons.water_drop_rounded, 'தண்ணீர் பிரச்சனை',  'Water',        'Leakages, Supply, etc.',   Color(0xFF2563EB)),
  _Cat('OTHER',        Icons.more_horiz_rounded, 'மற்றவை',           'Other',        'Other general issues',     Color(0xFF6B7280)),
];

// ── Main Screen ───────────────────────────────────────────────────────────────

class SubmitIssueScreen extends StatefulWidget {
  const SubmitIssueScreen({super.key});

  @override
  State<SubmitIssueScreen> createState() => _SubmitIssueScreenState();
}

class _SubmitIssueScreenState extends State<SubmitIssueScreen> {
  String _selectedCategory = 'ROAD_TRAFFIC';
  bool _isEmergency = false;
  final _descTaCtrl = TextEditingController();
  final _descEnCtrl = TextEditingController();

  // Location
  double _lat = 8.1833;
  double _lng = 77.4119;
  String _address = 'Nagercoil, Tamil Nadu';
  bool _locating = false;
  bool _locCaptured = false;

  // Photo
  Uint8List? _photo;
  String? _uploadedPhotoUrl;
  bool _uploading = false;
  
  bool _showAdvanced = false;

  // Stats (loaded async)
  Map<String, dynamic>? _stats;

  String get _lang => sl<LocalStorage>().getLang();
  bool get _isTa => _lang == 'ta';

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchLocation();
    _loadDraft();
    _descTaCtrl.addListener(_saveDraft);
    _descEnCtrl.addListener(_saveDraft);
  }

  void _loadDraft() {
    final storage = sl<LocalStorage>();
    _descTaCtrl.text = storage.getDraft('issue_draft_ta') ?? '';
    _descEnCtrl.text = storage.getDraft('issue_draft_en') ?? '';
  }

  void _saveDraft() {
    final storage = sl<LocalStorage>();
    storage.saveDraft('issue_draft_ta', _descTaCtrl.text);
    storage.saveDraft('issue_draft_en', _descEnCtrl.text);
  }


  @override
  void dispose() {
    _descTaCtrl.dispose();
    _descEnCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final res = await sl<ApiClient>().dio
          .get(ApiConstants.issueStats)
          .timeout(const Duration(seconds: 8));
      if (mounted) setState(() => _stats = res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _fetchLocation() async {
    if (mounted) setState(() => _locating = true);
    try {
      bool svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled) {
        _setDefaultLocation();
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        _setDefaultLocation();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _address = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}, Tamil Nadu';
          _locCaptured = true;
          _locating = false;
        });
      }
    } catch (_) {
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    if (mounted) setState(() { _locating = false; _locCaptured = false; });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() { _photo = bytes; _uploading = true; });
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'issue.jpg'),
      });
      final resp = await sl<ApiClient>().dio.post('/api/v1/media/upload', data: form);
      setState(() => _uploadedPhotoUrl = resp.data['url'] as String?);
    } catch (_) {
      setState(() => _photo = null);
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _submit() {
    // Require at least one description so blank issues can't be submitted.
    if (_descTaCtrl.text.trim().isEmpty && _descEnCtrl.text.trim().isEmpty) {
      final ta = sl<LocalStorage>().getLang() == 'ta';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(en: 'Please describe the issue before submitting', ta: 'தயவுசெய்து சிக்கலை விவரிக்கவும்', hi: 'कृपया सबमिट करने से पहले समस्या का विवरण दें', ml: 'സമർപ്പിക്കുന്നതിന് മുമ്പ് പ്രശ്നം വിവരിക്കുക')),
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }
    context.read<IssueBloc>().add(
          IssueSubmitRequested(
            category: _selectedCategory,
            descriptionTa: _descTaCtrl.text.trim(),
            descriptionEn: _descEnCtrl.text.trim(),
            latitude: _lat,
            longitude: _lng,
            photoUrl: _uploadedPhotoUrl,
          ),
        );
  }

  void _showCategoryExamples() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(en: 'Category examples', ta: 'வகை எடுத்துக்காட்டுகள்',
                    hi: 'श्रेणी उदाहरण', ml: 'വിഭാഗ ഉദാഹരണങ്ങൾ'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.cText),
              ),
              const SizedBox(height: 12),
              ..._categories.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(c.icon, size: 20, color: c.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_isTa ? c.labelTa : c.labelEn,
                                  style: TextStyle(fontWeight: FontWeight.w600, color: context.cText)),
                              Text(c.subtitleEn,
                                  style: TextStyle(fontSize: 12, color: context.cTextSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cSurface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(en: 'Report an Issue', ta: 'பிரச்சனை தெரிவிக்கவும்', hi: 'समस्या की रिपोर्ट करें', ml: 'പ്രശ്നം റിപ്പോർട്ട് ചെയ്യുക'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.cText),
            ),
            Text(
              tr(en: 'Help us improve Nagercoil', ta: 'நாகர்கோவிலை மேம்படுத்த உதவுங்கள்', hi: 'नागरकोइल को बेहतर बनाने में मदद करें', ml: 'നാഗർകോവിൽ മെച്ചപ്പെടുത്താൻ സഹായിക്കൂ'),
              style: TextStyle(fontSize: 10, color: context.cTextSecondary),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/issues/track'),
            icon: Icon(Icons.list_alt_rounded, size: 16, color: AppColors.primary),
            label: Text(
              tr(en: 'My Reports', ta: 'என் புகார்கள்', hi: 'मेरी रिपोर्ट', ml: 'എന്റെ റിപ്പോർട്ടുകൾ'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: BlocListener<IssueBloc, IssueState>(
        listener: (context, state) {
          if (state is IssueSubmitSuccess) {
            final storage = sl<LocalStorage>();
            storage.clearDraft('issue_draft_ta');
            storage.clearDraft('issue_draft_en');
            _descTaCtrl.clear();
            _descEnCtrl.clear();
            _showSuccessSheet(context, state.issue.id);
          }
          if (state is IssueFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.accent,
                action: SnackBarAction(
                  label: tr(en: 'Retry', ta: 'மீண்டும் முயற்சி', hi: 'पुनः प्रयास', ml: 'വീണ്ടും ശ്രമിക്കുക'),
                  textColor: Colors.white,
                  onPressed: _submit,
                ),
              ),
            );
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats row
            _StatsRow(stats: _stats),
            const SizedBox(height: 16),

            // 3-step process banner
            const _ProcessBanner(),
            const SizedBox(height: 16),

            // Emergency button
            _EmergencyBanner(
              isActive: _isEmergency,
              isTa: _isTa,
              onToggle: (v) => setState(() => _isEmergency = v),
            ),
            const SizedBox(height: 20),

            // Category grid
            _SectionLabel(
              tr(en: 'Select Category', ta: 'வகை தேர்வு', hi: 'श्रेणी चुनें', ml: 'വിഭാഗം തിരഞ്ഞെടുക്കുക'),
              trailing: _isTa ? null : tr(en: 'Not sure? See examples', ta: '', hi: 'पक्का नहीं? उदाहरण देखें', ml: 'ഉറപ്പില്ലേ? ഉദാഹരണങ്ങൾ കാണുക'),
              onTrailingTap: _showCategoryExamples,
            ),
            const SizedBox(height: 10),
            _CategoryGrid(
              selected: _selectedCategory,
              isTa: _isTa,
              onSelect: (c) => setState(() => _selectedCategory = c),
            ),
            const SizedBox(height: 20),

            // Advanced settings toggle
            GestureDetector(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showAdvanced ? (tr(en: 'Hide Details', ta: 'மேலும் விவரங்களை மறை', hi: 'विवरण छिपाएं', ml: 'വിശദാംശങ്ങൾ മറയ്ക്കുക')) : (tr(en: 'Add Details (Optional)', ta: 'மேலும் விவரங்கள் (விருப்பமானவை)', hi: 'विवरण जोड़ें (वैकल्पिक)', ml: 'വിശദാംശങ്ങൾ ചേർക്കുക (ഓപ്ഷണൽ)')),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                  Icon(
                    _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (_showAdvanced) ...[
              // Description — Tamil
              _SectionLabel(tr(en: 'Description (Tamil)', ta: 'விவரம் (தமிழ்)', hi: 'विवरण (तमिल)', ml: 'വിവരണം (തമിഴ്)')),
              const SizedBox(height: 8),
              TextField(
                controller: _descTaCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'இங்கே தமிழில் எழுதுங்கள்...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.cBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description — English
              _SectionLabel(tr(en: 'Description (English)', ta: 'விவரம் (ஆங்கிலம்)', hi: 'विवरण (अंग्रेज़ी)', ml: 'വിവരണം (ഇംഗ്ലീഷ്)')),
              const SizedBox(height: 8),
              TextField(
                controller: _descEnCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Describe the issue in English...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.cBorder),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Photo Evidence
            _SectionLabel(
              tr(en: 'Photo Evidence', ta: 'புகைப்படம் (ஆதாரம்)', hi: 'फ़ोटो प्रमाण', ml: 'ഫോട്ടോ തെളിവ്'),
              badge: tr(en: 'Captured Automatically', ta: 'தானாகப் பதிவாகும்', hi: 'स्वतः कैप्चर', ml: 'സ്വയമേവ പകർത്തി'),
            ),
            const SizedBox(height: 8),
            _PhotoSection(
              photo: _photo,
              uploading: _uploading,
              onPick: _pickPhoto,
              isTa: _isTa,
            ),
            const SizedBox(height: 16),

            // Location
            _SectionLabel(
              tr(en: 'Auto Location', ta: 'இடம்', hi: 'स्वतः स्थान', ml: 'സ്വയം ലൊക്കേഷൻ'),
              badge: _locCaptured ? (tr(en: 'Captured Automatically', ta: 'தானாகப் பெறப்பட்டது', hi: 'स्वतः प्राप्त', ml: 'സ്വയമേവ ലഭിച്ചു')) : null,
            ),
            const SizedBox(height: 8),
            _LocationCard(
              lat: _lat,
              lng: _lng,
              address: _address,
              locating: _locating,
              captured: _locCaptured,
              onRecapture: _fetchLocation,
              isTa: _isTa,
            ),
            const SizedBox(height: 24),

            // "We'll do the rest" footer
            const _WellDoTheRestCard(),
            const SizedBox(height: 20),

            // Submit
            BlocBuilder<IssueBloc, IssueState>(
              builder: (context, state) {
                final loading = state is IssueLoading;
                return SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEmergency ? const Color(0xFFDC2626) : AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isEmergency ? Icons.emergency_rounded : Icons.send_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _isEmergency
                                    ? (tr(en: 'Send Emergency Report', ta: 'அவசர புகார் அனுப்பவும்', hi: 'आपातकालीन रिपोर्ट भेजें', ml: 'അടിയന്തര റിപ്പോർട്ട് അയയ്ക്കുക'))
                                    : (tr(en: 'Submit Issue', ta: 'புகார் அனுப்பவும்', hi: 'समस्या सबमिट करें', ml: 'പ്രശ്നം സമർപ്പിക്കുക')),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                tr(en: 'Your data is safe with us. We never share your personal info.', ta: 'உங்கள் தகவல் பாதுகாக்கப்படும். யாரிடமும் பகிர்வதில்லை.', hi: 'आपका डेटा हमारे पास सुरक्षित है। हम आपकी निजी जानकारी कभी साझा नहीं करते।', ml: 'നിങ്ങളുടെ വിവരങ്ങൾ ഞങ്ങളുടെ പക്കൽ സുരക്ഷിതമാണ്. നിങ്ങളുടെ വ്യക്തിവിവരം ഞങ്ങൾ പങ്കിടില്ല.'),
                style: TextStyle(fontSize: 10.5, color: context.cTextSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showSuccessSheet(BuildContext context, String issueId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(
        issueId: issueId.substring(0, 8).toUpperCase(),
        isEmergency: _isEmergency,
        isTa: _isTa,
        onTrack: () {
          Navigator.of(context).pop();
          context.push('/issues/track');
        },
        onDone: () {
          Navigator.of(context).pop();
          context.pop();
        },
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final String? trailing;
  final String? badge;
  final VoidCallback? onTrailingTap;
  const _SectionLabel(this.text, {this.trailing, this.badge, this.onTrailingTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.cText)),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
        const Spacer(),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(trailing!, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic>? stats;
  const _StatsRow({this.stats});

  @override
  Widget build(BuildContext context) {
    final resolved = stats?['resolved']?.toString() ?? '—';
    final rate = stats != null ? '${stats!['resolution_rate']}%' : '—';
    final days = stats != null ? '${stats!['avg_response_days']} Days' : '—';
    final citizens = stats?['active_citizens'] != null
        ? '${((stats!['active_citizens'] as int) / 1000).toStringAsFixed(1)}K'
        : '—';

    final items = [
      (resolved,  'Issues Resolved', const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
      (rate,      'Resolution Rate',  const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
      (days,      'Avg. Response',    const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
      (citizens,  'Active Citizens',  const Color(0xFFD97706), const Color(0xFFFFFBEB)),
    ];

    return Row(
      children: items.map((s) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: s == items.last ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: context.isDark ? s.$3.withOpacity(0.15) : s.$4,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: s.$3.withOpacity(context.isDark ? 0.25 : 0.18)),
            ),
            child: Column(
              children: [
                Text(s.$1,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: s.$3)),
                const SizedBox(height: 2),
                Text(s.$2,
                    style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w600, color: context.cTextSecondary),
                    textAlign: TextAlign.center, maxLines: 2),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 3-Step Process Banner ─────────────────────────────────────────────────────

class _ProcessBanner extends StatelessWidget {
  const _ProcessBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF0F2D1A) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report in 3 Simple Steps',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: context.isDark ? AppColors.primaryLight : AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _Step(icon: Icons.location_on_rounded,    label: 'Auto Location\nCaptured',    color: Color(0xFF16A34A)),
              _StepArrow(),
              _Step(icon: Icons.email_rounded,          label: 'Auto Mail\nto Department',  color: Color(0xFF2563EB)),
              _StepArrow(),
              _Step(icon: Icons.groups_rounded,         label: 'Followed by\nFYC Team',     color: Color(0xFF7C3AED)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Step({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: context.cTextSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Icon(Icons.chevron_right_rounded, color: context.cTextSecondary, size: 20),
      );
}

// ── Emergency Banner ──────────────────────────────────────────────────────────

class _EmergencyBanner extends StatelessWidget {
  final bool isActive, isTa;
  final ValueChanged<bool> onToggle;
  const _EmergencyBanner({required this.isActive, required this.isTa, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!isActive),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFDC2626).withOpacity(0.12) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? const Color(0xFFDC2626) : const Color(0xFFDC2626).withOpacity(0.35),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(en: 'Emergency Issue?', ta: 'அவசர புகார்!', hi: 'आपातकालीन समस्या?', ml: 'അടിയന്തര പ്രശ്നമോ?'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                  ),
                  Text(
                    tr(en: 'Report urgent hazards that need immediate attention.', ta: 'உடனடி கவனிப்பு தேவைப்படும் தீவிர பிரச்சனைகளுக்கு', hi: 'तुरंत ध्यान देने योग्य गंभीर खतरों की रिपोर्ट करें।', ml: 'ഉടനടി ശ്രദ്ധ വേണ്ട ഗുരുതര അപകടങ്ങൾ റിപ്പോർട്ട് ചെയ്യുക.'),
                    style: TextStyle(fontSize: 11, color: const Color(0xFFDC2626).withOpacity(0.75)),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isActive,
              onChanged: onToggle,
              activeColor: const Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Grid ─────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final String selected;
  final bool isTa;
  final void Function(String) onSelect;
  const _CategoryGrid({required this.selected, required this.isTa, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: _categories.map((cat) {
        final isSelected = cat.id == selected;
        return GestureDetector(
          onTap: () => onSelect(cat.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? cat.color.withOpacity(0.12) : context.cSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? cat.color : context.cBorder,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: cat.color.withOpacity(0.20), blurRadius: 8, offset: const Offset(0, 3))]
                  : context.isDark ? null : AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cat.icon, size: 26, color: cat.color),
                const SizedBox(height: 4),
                Text(
                  isTa ? cat.labelTa : cat.labelEn,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? cat.color : context.cText,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
                Text(
                  cat.subtitleEn,
                  style: TextStyle(fontSize: 7.5, color: context.cTextSecondary),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Photo Section ─────────────────────────────────────────────────────────────

class _PhotoSection extends StatelessWidget {
  final Uint8List? photo;
  final bool uploading, isTa;
  final VoidCallback onPick;
  const _PhotoSection({required this.photo, required this.uploading, required this.onPick, required this.isTa});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hints
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hint(tr(en: 'Clear photo helps', ta: 'தெளிவான புகைப்படம் உதவும்', hi: 'साफ़ फ़ोटो मदद करती है', ml: 'വ്യക്തമായ ഫോട്ടോ സഹായിക്കും'), icon: Icons.check_circle_outline),
              _Hint(tr(en: 'Show the exact problem area', ta: 'சாலை ஓரத்தை முழுதாக காட்டவும்', hi: 'सटीक समस्या क्षेत्र दिखाएं', ml: 'കൃത്യമായ പ്രശ്ന പ്രദേശം കാണിക്കുക'), icon: Icons.check_circle_outline),
              _Hint(tr(en: 'Multiple photos are welcome', ta: 'பல புகைப்படங்கள் வரவேற்கப்படும்', hi: 'कई फ़ोटो स्वागत योग्य हैं', ml: 'ഒന്നിലധികം ഫോട്ടോകൾ സ്വാഗതം'), icon: Icons.check_circle_outline),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Photo widget
        GestureDetector(
          onTap: uploading ? null : onPick,
          child: Container(
            width: 110,
            height: 100,
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1E2020) : Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: photo != null ? AppColors.primary : context.cBorder,
                width: photo != null ? 2 : 1,
              ),
            ),
            child: uploading
                ? const Center(child: CircularProgressIndicator())
                : photo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.memory(photo!, fit: BoxFit.cover, width: 110, height: 100),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_rounded, color: context.cTextSecondary, size: 28),
                          const SizedBox(height: 4),
                          Text(
                            tr(en: 'Take Photo', ta: 'படம் எடு', hi: 'फ़ोटो लें', ml: 'ഫോട്ടോ എടുക്കുക'),
                            style: TextStyle(fontSize: 10, color: context.cTextSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Hint(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: context.cTextSecondary))),
        ],
      ),
    );
  }
}

// ── Location Card ─────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final double lat, lng;
  final String address;
  final bool locating, captured, isTa;
  final VoidCallback onRecapture;
  const _LocationCard({
    required this.lat,
    required this.lng,
    required this.address,
    required this.locating,
    required this.captured,
    required this.onRecapture,
    required this.isTa,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: captured ? AppColors.primary.withOpacity(0.4) : context.cBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (captured ? AppColors.primary : Colors.grey).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    captured ? Icons.location_on_rounded : Icons.location_off_rounded,
                    color: captured ? AppColors.primary : Colors.grey,
                    size: 18,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cText),
                ),
                Text(
                  address,
                  style: TextStyle(fontSize: 10.5, color: context.cTextSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: locating ? null : onRecapture,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: Text(
              tr(en: 'Re-Capture', ta: 'மீண்டும்', hi: 'फिर से कैप्चर', ml: 'വീണ്ടും പകർത്തുക'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── "We'll do the rest" card ──────────────────────────────────────────────────

class _WellDoTheRestCard extends StatelessWidget {
  const _WellDoTheRestCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF0F2D1A) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'We\'ll do the rest!',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.isDark ? AppColors.primaryLight : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _RestStep(icon: Icons.assignment_ind_rounded, label: 'Auto-assigned\nto department', color: Color(0xFF2563EB)),
              _RestStep(icon: Icons.groups_rounded,         label: 'FYC Team\nnotified',           color: Color(0xFF7C3AED)),
              _RestStep(icon: Icons.verified_rounded,       label: 'Resolved\n& closed',           color: Color(0xFF16A34A)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _RestStep({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(fontSize: 9.5, color: context.cTextSecondary, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ],
    );
  }
}

// ── Success Bottom Sheet ──────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  final String issueId;
  final bool isEmergency, isTa;
  final VoidCallback onTrack, onDone;
  const _SuccessSheet({
    required this.issueId,
    required this.isEmergency,
    required this.isTa,
    required this.onTrack,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: BoxDecoration(
        color: context.cBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEmergency ? const Color(0xFFDC2626).withOpacity(0.12) : AppColors.primary.withOpacity(0.10),
            ),
            child: Icon(
              isEmergency ? Icons.emergency_rounded : Icons.check_circle_rounded,
              size: 48,
              color: isEmergency ? const Color(0xFFDC2626) : AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEmergency
                ? (tr(en: 'Emergency Reported!', ta: 'அவசர புகார் பதிவாகியுள்ளது!', hi: 'आपातकाल की रिपोर्ट दर्ज!', ml: 'അടിയന്തരാവസ്ഥ റിപ്പോർട്ട് ചെയ്തു!'))
                : (tr(en: 'Issue Submitted Successfully!', ta: 'புகார் வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது!', hi: 'समस्या सफलतापूर्वक सबमिट हुई!', ml: 'പ്രശ്നം വിജയകരമായി സമർപ്പിച്ചു!')),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.cBorder),
            ),
            child: Text(
              'Issue ID: #$issueId',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr(en: 'Our team will review and act within 24 hours. Thank you for making Nagercoil better!', ta: 'நம் குழு 24 மணி நேரத்தில் ஆய்வு செய்து செயல்படும். நன்றி!', hi: 'हमारी टीम 24 घंटे में समीक्षा कर कार्रवाई करेगी। नागरकोइल को बेहतर बनाने के लिए धन्यवाद!', ml: 'ഞങ്ങളുടെ ടീം 24 മണിക്കൂറിനുള്ളിൽ പരിശോധിച്ച് നടപടിയെടുക്കും. നാഗർകോവിൽ മെച്ചപ്പെടുത്തിയതിന് നന്ദി!'),
            style: TextStyle(fontSize: 12.5, color: context.cTextSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTrack,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(tr(en: 'Track Issue', ta: 'புகார் கண்காணிக்கவும்', hi: 'समस्या ट्रैक करें', ml: 'പ്രശ്നം ട്രാക്ക് ചെയ്യുക'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text(tr(en: 'Done', ta: 'முடிந்தது', hi: 'हो गया', ml: 'പൂർത്തിയായി'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
