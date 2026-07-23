import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../service_locator.dart';
import '../auth/presentation/bloc/auth_bloc.dart';
import '../auth/presentation/bloc/auth_state.dart';
import 'feed_api.dart';
import '../../core/services/sync_service.dart';

const _categories = ['All', 'Cricket', 'Events', 'Environment', 'Achievements', 'Announcement', 'Other'];

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _controller = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<File> _images = [];
  bool _posting = false;
  bool _shareToInstagram = false;
  bool _showLocation = false;
  String _category = 'All';
  List<String> _recentTags = const [];

  bool get _ta => sl<LocalStorage>().getLang() == 'ta';

  String get _authorName {
    final s = context.read<AuthBloc>().state;
    if (s is AuthAuthenticated) {
      return (_ta ? s.user.fullNameTa : s.user.fullNameEn) ?? s.user.fullNameEn ?? 'You';
    }
    return 'You';
  }

  String get _roleLabel {
    final s = context.read<AuthBloc>().state;
    if (s is! AuthAuthenticated) return 'Member';
    switch (s.user.role) {
      case 'ADMIN':
      case 'SUPER_ADMIN':
        return 'Admin';
      case 'EXECUTIVE_MEMBER':
        return 'Manager';
      case 'VOLUNTEER':
        return 'Volunteer';
      default:
        return 'Member';
    }
  }

  bool get _isManager {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.isAdmin;
  }

  @override
  void initState() {
    super.initState();
    FeedApi.recentHashtags().then((t) {
      if (mounted) setState(() => _recentTags = t);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 4) return;
    try {
      // Support both images and videos (D1 requirement)
      final x = await _picker.pickMedia(imageQuality: 70, maxWidth: 1600);
      if (x != null) setState(() => _images.add(File(x.path)));
    } catch (_) {}
  }

  void _appendTag(String tag) {
    final t = _controller.text;
    final needsSpace = t.isNotEmpty && !t.endsWith(' ');
    _controller.text = '$t${needsSpace ? ' ' : ''}$tag ';
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    setState(() {});
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty) return;
    setState(() => _posting = true);
    try {
      // Queue the post with LOCAL image paths — SyncService uploads them when
      // the network is available. This is what lets a media post survive being
      // composed offline instead of failing at the upload step.
      await SyncService.enqueuePost(
        content: text,
        localImagePaths: _images.map((f) => f.path).toList(),
        category: _category == 'All' ? null : _category,
        location: _showLocation ? _locationCtrl.text : null,
        shareToInstagram: _shareToInstagram && _images.isNotEmpty,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(en: "Couldn't post. Please try again.",
            ta: 'இட முடியவில்லை. மீண்டும் முயற்சி.',
            hi: 'पोस्ट नहीं हुआ। पुनः प्रयास करें।',
            ml: 'പോസ്റ്റ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക.')),
        backgroundColor: AppColors.accent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPost = !_posting && (_controller.text.trim().isNotEmpty || _images.isNotEmpty);
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        backgroundColor: context.cSurface,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(tr(en: 'Create Post', ta: 'இடுகையை உருவாக்கு',
            hi: 'पोस्ट बनाएं', ml: 'പോസ്റ്റ് സൃഷ്ടിക്കുക'),
            style: TextStyle(color: context.cText, fontWeight: FontWeight.w800, fontSize: 17)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: canPost ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _posting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(tr(en: 'Post', ta: 'இடு', hi: 'पोस्ट', ml: 'പോസ്റ്റ്'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: canPost ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _posting
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(
                    tr(en: 'Post Update', ta: 'இடுகையை வெளியிடு', hi: 'पोस्ट करें', ml: 'പോസ്റ്റ് ചെയ്യുക'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40),
        children: [
          // Author + role + audience
          Row(
            children: [
              CircleAvatar(radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(_authorName.isNotEmpty ? _authorName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_authorName, style: TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 15, color: context.cText)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_roleLabel, style: const TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.cBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.public, size: 15),
                  const SizedBox(width: 5),
                  Text(tr(en: 'Public', ta: 'பொது', hi: 'सार्वजनिक', ml: 'പൊതു'),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.cText)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Text area with counter
          Container(
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cBorder),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _controller,
                  maxLines: null,
                  minLines: 5,
                  maxLength: 500,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 15, color: context.cText),
                  decoration: InputDecoration(
                    hintText: tr(en: "What's happening in your community?",
                        ta: 'உங்கள் சமூகத்தில் என்ன நடக்கிறது?',
                        hi: 'आपके समुदाय में क्या हो रहा है?',
                        ml: 'നിങ്ങളുടെ സമൂഹത്തിൽ എന്താണ്?'),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                Text('${_controller.text.length}/500',
                    style: TextStyle(fontSize: 11, color: context.cTextSecondary)),
              ],
            ),
          ),

          // Selected images
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                for (int i = 0; i < _images.length; i++)
                  Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12),
                        child: Image.file(_images[i], width: 96, height: 96, fit: BoxFit.cover)),
                    Positioned(right: 2, top: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close, color: Colors.white, size: 15),
                        ),
                      ),
                    ),
                  ]),
              ],
            ),
          ],
          const SizedBox(height: 12),

          _OutlineAction(
            icon: Icons.image_outlined,
            label: tr(en: 'Add Photos / Videos', ta: 'படங்கள் / வீடியோ சேர்',
                hi: 'फ़ोटो / वीडियो जोड़ें', ml: 'ഫോട്ടോ / വീഡിയോ ചേർക്കുക'),
            onTap: _images.length >= 4 ? null : _pickImage,
          ),
          const SizedBox(height: 10),
          _OutlineAction(
            icon: Icons.location_on_outlined,
            label: _showLocation
                ? tr(en: 'Remove Location', ta: 'இடத்தை நீக்கு', hi: 'स्थान हटाएं', ml: 'സ്ഥലം നീക്കുക')
                : tr(en: 'Add Location', ta: 'இடத்தைச் சேர்', hi: 'स्थान जोड़ें', ml: 'സ്ഥലം ചേർക്കുക'),
            onTap: () => setState(() => _showLocation = !_showLocation),
          ),
          if (_showLocation) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                hintText: tr(en: 'Where?', ta: 'எங்கே?', hi: 'कहाँ?', ml: 'എവിടെ?'),
                prefixIcon: const Icon(Icons.place_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Quick actions (Sprint 4: Poll, Event, Tournament, Volunteer)
          Text('Quick Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.cText)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickActionBtn(
                  icon: Icons.poll_outlined,
                  color: const Color(0xFF3B82F6),
                  label: 'Poll',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon: Create Poll'))),
                ),
                _QuickActionBtn(
                  icon: Icons.event_outlined,
                  color: const Color(0xFF8B5CF6),
                  label: 'Event',
                  onTap: () {
                    Navigator.pop(context); // Close create post sheet
                    context.push('/events'); // Or wherever event creation is
                  },
                ),
                _QuickActionBtn(
                  icon: Icons.emoji_events_outlined,
                  color: const Color(0xFFD97706),
                  label: 'Tournament',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/sports/create');
                  },
                ),
                _QuickActionBtn(
                  icon: Icons.volunteer_activism_outlined,
                  color: const Color(0xFFEF4444),
                  label: 'Volunteer',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/opportunities');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Instagram toggle (managers only)
          if (_isManager)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.cSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.cBorder),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.camera_alt_outlined, color: Color(0xFFC13584)),
                title: Text(tr(en: 'Also share to Instagram', ta: 'இன்ஸ்டாகிராமிலும் பகிர்',
                    hi: 'इंस्टाग्राम पर भी साझा करें', ml: 'ഇൻസ്റ്റാഗ്രാമിലും പങ്കിടുക'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.cText)),
                subtitle: Text(tr(en: 'If you add media, it will also be posted to the club Instagram page.',
                    ta: 'படம் சேர்த்தால் கிளப் இன்ஸ்டாகிராமிலும் இடப்படும்.',
                    hi: 'मीडिया जोड़ने पर क्लब इंस्टाग्राम पर भी पोस्ट होगा।',
                    ml: 'മീഡിയ ചേർത്താൽ ക്ലബ് ഇൻസ്റ്റാഗ്രാമിലും പോസ്റ്റ് ചെയ്യും.'),
                    style: TextStyle(fontSize: 11.5, color: context.cTextSecondary)),
                value: _shareToInstagram,
                onChanged: (v) => setState(() => _shareToInstagram = v),
              ),
            ),
          if (_isManager) const SizedBox(height: 18),

          // Category
          Text(tr(en: 'Choose Category', ta: 'வகையைத் தேர்ந்தெடு',
              hi: 'श्रेणी चुनें', ml: 'വിഭാഗം തിരഞ്ഞെടുക്കുക'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.cText)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _categories.map((c) {
              final selected = _category == c;
              return GestureDetector(
                onTap: () => setState(() => _category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : context.cSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppColors.primary : context.cBorder),
                  ),
                  child: Text(c, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : context.cText)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // How it works
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(tr(en: 'How it works', ta: 'எப்படி வேலை செய்கிறது',
                      hi: 'यह कैसे काम करता है', ml: 'എങ്ങനെ പ്രവർത്തിക്കുന്നു'),
                      style: TextStyle(fontWeight: FontWeight.w800, color: context.cText)),
                  const Spacer(),
                  Icon(Icons.info_outline, size: 16, color: context.cTextSecondary),
                ]),
                const SizedBox(height: 10),
                _HowRow(icon: Icons.chat_bubble_outline, iconColor: AppColors.primary,
                    title: tr(en: 'Text only', ta: 'உரை மட்டும்', hi: 'केवल टेक्स्ट', ml: 'ടെക്സ്റ്റ് മാത്രം'),
                    subtitle: tr(en: 'Posted to Thread (Community Feed)', ta: 'சுவரில் இடப்படும்',
                        hi: 'थ्रेड में पोस्ट', ml: 'ത്രെഡിൽ പോസ്റ്റ്')),
                const SizedBox(height: 10),
                _HowRow(icon: Icons.camera_alt_outlined, iconColor: const Color(0xFFC13584),
                    title: tr(en: 'With Photos / Videos', ta: 'படம் / வீடியோவுடன்',
                        hi: 'फ़ोटो / वीडियो के साथ', ml: 'ഫോട്ടോ / വീഡിയോയോടെ'),
                    subtitle: tr(en: 'Posted to Instagram + Thread', ta: 'இன்ஸ்டாகிராம் + சுவர்',
                        hi: 'इंस्टाग्राम + थ्रेड', ml: 'ഇൻസ്റ്റാഗ്രാം + ത്രെഡ്')),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Guidelines
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(en: 'Community Guidelines', ta: 'சமூக வழிகாட்டுதல்கள்',
                    hi: 'समुदाय दिशानिर्देश', ml: 'കമ്മ്യൂണിറ്റി മാർഗ്ഗനിർദ്ദേശങ്ങൾ'),
                    style: TextStyle(fontWeight: FontWeight.w800, color: context.cText)),
                const SizedBox(height: 8),
                for (final g in [
                  tr(en: 'Be respectful and positive', ta: 'மரியாதையாக இருங்கள்',
                      hi: 'सम्मानजनक रहें', ml: 'ബഹുമാനത്തോടെ ഇരിക്കുക'),
                  tr(en: 'No hate speech or bullying', ta: 'வெறுப்பு பேச்சு வேண்டாம்',
                      hi: 'नफ़रत नहीं', ml: 'വിദ്വേഷം വേണ്ട'),
                  tr(en: 'No spam or irrelevant content', ta: 'ஸ்பேம் வேண்டாம்',
                      hi: 'स्पैम नहीं', ml: 'സ്പാം വേണ്ട'),
                  tr(en: 'Keep our community clean and safe', ta: 'சமூகத்தை பாதுகாப்பாக வைக்கவும்',
                      hi: 'समुदाय को सुरक्षित रखें', ml: 'സമൂഹത്തെ സുരക്ഷിതമായി സൂക്ഷിക്കുക'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.check, size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(g, style: TextStyle(fontSize: 12.5, color: context.cText))),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Recent hashtags
          if (_recentTags.isNotEmpty) ...[
            Text(tr(en: 'Recent Hashtags', ta: 'சமீபத்திய ஹேஷ்டேக்',
                hi: 'हाल के हैशटैग', ml: 'സമീപകാല ഹാഷ്ടാഗുകൾ'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.cText)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _recentTags.map((t) => GestureDetector(
                onTap: () => _appendTag(t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: context.cSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.cBorder),
                  ),
                  child: Text(t, style: const TextStyle(fontSize: 12.5,
                      fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _OutlineAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _HowRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  const _HowRow({required this.icon, required this.iconColor,
      required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.cText)),
              Text(subtitle, style: TextStyle(fontSize: 11.5, color: context.cTextSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color.withOpacity(context.isDark ? 0.9 : 1.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
