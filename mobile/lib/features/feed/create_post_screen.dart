import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../service_locator.dart';
import '../auth/presentation/bloc/auth_bloc.dart';
import '../auth/presentation/bloc/auth_state.dart';
import 'feed_api.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final List<File> _images = [];
  bool _posting = false;
  bool _shareToInstagram = false;

  bool get _ta => sl<LocalStorage>().getLang() == 'ta';

  bool get _isAdmin {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.isAdmin;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_images.length >= 4) return;
    try {
      final x = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
      if (x != null) setState(() => _images.add(File(x.path)));
    } catch (_) {/* permission denied / cancelled */}
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty) return;
    setState(() => _posting = true);
    final ta = _ta;
    try {
      final urls = <String>[];
      for (final f in _images) {
        urls.add(await FeedApi.uploadImage(f.path));
      }
      await FeedApi.create(
        content: text,
        imageUrls: urls,
        shareToInstagram: _shareToInstagram && urls.isNotEmpty,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(
            en: "Couldn't post. Please try again.",
            ta: 'இடுகையிட முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
            hi: 'पोस्ट नहीं हो सका। कृपया पुनः प्रयास करें।',
            ml: 'പോസ്റ്റ് ചെയ്യാനായില്ല. വീണ്ടും ശ്രമിക്കുക.')),
        backgroundColor: AppColors.accent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = _ta;
    final canPost =
        !_posting && (_controller.text.trim().isNotEmpty || _images.isNotEmpty);
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        title: Text(tr(
            en: 'Create Post',
            ta: 'இடுகையை உருவாக்கு',
            hi: 'पोस्ट बनाएं',
            ml: 'പോസ്റ്റ് സൃഷ്ടിക്കുക')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: canPost ? _submit : null,
              child: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      tr(en: 'Post', ta: 'இடு', hi: 'पोस्ट', ml: 'പോസ്റ്റ്'),
                      style: TextStyle(
                          color: canPost
                              ? AppColors.primary
                              : context.cTextSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            maxLines: null,
            minLines: 4,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 16, color: context.cText),
            decoration: InputDecoration(
              hintText: tr(
                  en: "What's happening in your community?",
                  ta: 'உங்கள் சமூகத்தில் என்ன நடக்கிறது?',
                  hi: 'आपके समुदाय में क्या हो रहा है?',
                  ml: 'നിങ്ങളുടെ സമൂഹത്തിൽ എന്താണ് നടക്കുന്നത്?'),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 12),
          if (_images.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _images.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_images[i],
                            width: 100, height: 100, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _images.length >= 4 ? null : _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(tr(
                en: 'Add Photo',
                ta: 'புகைப்படம் சேர்',
                hi: 'फ़ोटो जोड़ें',
                ml: 'ഫോട്ടോ ചേർക്കുക')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          // Admins/managers can mirror an image post to the club's Instagram.
          if (_isAdmin && _images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.camera_alt_outlined, color: Color(0xFFC13584)),
              title: Text(tr(
                  en: 'Also share to Instagram',
                  ta: 'இன்ஸ்டாகிராமிலும் பகிர்',
                  hi: 'इंस्टाग्राम पर भी साझा करें',
                  ml: 'ഇൻസ്റ്റാഗ്രാമിലും പങ്കിടുക')),
              subtitle: Text(tr(
                  en: 'Posts the first photo to the club Instagram page',
                  ta: 'முதல் புகைப்படம் கிளப் இன்ஸ்டாகிராமில் இடப்படும்',
                  hi: 'पहली फ़ोटो क्लब इंस्टाग्राम पर पोस्ट होगी',
                  ml: 'ആദ്യ ഫോട്ടോ ക്ലബ് ഇൻസ്റ്റാഗ്രാമിൽ പോസ്റ്റ് ചെയ്യും')),
              value: _shareToInstagram,
              onChanged: (v) => setState(() => _shareToInstagram = v),
            ),
          ],
        ],
      ),
    );
  }
}
