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
        return trId('volunteer');
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
        content: Text(trId('couldn_t_post_please_try_again')),
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
        leading: IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(trId('create_post'),
            style: TextStyle(color: context.cText, fontWeight: FontWeight.w800, fontSize: 17)),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 10, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: canPost ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _posting
                  ? SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2))
                  : Text(trId('post_2'),
                      style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
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
                ? SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(color: AppColors.background, strokeWidth: 2.5))
                : Text(
                    trId('post_update'),
                    style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40),
        children: [
          // Author + role + audience
          Row(
            children: [
              CircleAvatar(radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(_authorName.isNotEmpty ? _authorName[0].toUpperCase() : '?',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_authorName, style: TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 15, color: context.cText)),
                    SizedBox(height: 2),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_roleLabel, style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.cBorder),
                ),
                child: Row(children: [
                  Icon(Icons.public, size: 15),
                  SizedBox(width: 5),
                  Text(trId('public'),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.cText)),
                ]),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Text area with counter
          Container(
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cBorder),
            ),
            padding: EdgeInsets.all(12),
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
                    hintText: trId('what_s_happening_in_your_community'),
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
            SizedBox(height: 12),
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
                          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close, color: AppColors.background, size: 15),
                        ),
                      ),
                    ),
                  ]),
              ],
            ),
          ],
          SizedBox(height: 12),

          _OutlineAction(
            icon: Icons.image_outlined,
            label: trId('add_photos_videos'),
            onTap: _images.length >= 4 ? null : _pickImage,
          ),
          SizedBox(height: 10),
          _OutlineAction(
            icon: Icons.location_on_outlined,
            label: _showLocation
                ? trId('remove_location')
                : trId('add_location'),
            onTap: () => setState(() => _showLocation = !_showLocation),
          ),
          if (_showLocation) ...[
            SizedBox(height: 10),
            TextField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                hintText: trId('where'),
                prefixIcon: Icon(Icons.place_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ],
          SizedBox(height: 16),

          // Quick actions (Sprint 4: Poll, Event, Tournament, Volunteer)
          Text(trId('quick_actions'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.cText)),
          SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickActionBtn(
                  icon: Icons.poll_outlined,
                  color: const Color(0xFF3B82F6),
                  label: trId('poll'),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(trId('coming_soon_create_poll')))),
                ),
                _QuickActionBtn(
                  icon: Icons.event_outlined,
                  color: const Color(0xFF8B5CF6),
                  label: trId('event'),
                  onTap: () {
                    Navigator.pop(context); // Close create post sheet
                    context.push('/events'); // Or wherever event creation is
                  },
                ),
                _QuickActionBtn(
                  icon: Icons.emoji_events_outlined,
                  color: const Color(0xFFD97706),
                  label: trId('tournament'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/sports/create');
                  },
                ),
                _QuickActionBtn(
                  icon: Icons.volunteer_activism_outlined,
                  color: const Color(0xFFEF4444),
                  label: trId('volunteer'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/work');
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Instagram toggle (managers only)
          if (_isManager)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.cSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.cBorder),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(Icons.camera_alt_outlined, color: Color(0xFFC13584)),
                title: Text(trId('also_share_to_instagram'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.cText)),
                subtitle: Text(trId('if_you_add_media_it_will_also_be_posted'),
                    style: TextStyle(fontSize: 11.5, color: context.cTextSecondary)),
                value: _shareToInstagram,
                onChanged: (v) => setState(() => _shareToInstagram = v),
              ),
            ),
          if (_isManager) SizedBox(height: 18),

          // Category
          Text(trId('choose_category'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.cText)),
          SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _categories.map((c) {
              final selected = _category == c;
              return GestureDetector(
                onTap: () => setState(() => _category = c),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : context.cSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppColors.primary : context.cBorder),
                  ),
                  child: Text(c, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                      color: selected ? AppColors.background : context.cText)),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 18),

          // How it works
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.cBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(trId('how_it_works'),
                      style: TextStyle(fontWeight: FontWeight.w800, color: context.cText)),
                  Spacer(),
                  Icon(Icons.info_outline, size: 16, color: context.cTextSecondary),
                ]),
                SizedBox(height: 10),
                _HowRow(icon: Icons.chat_bubble_outline, iconColor: AppColors.primary,
                    title: trId('text_only'),
                    subtitle: trId('posted_to_thread_community_feed')),
                SizedBox(height: 10),
                _HowRow(icon: Icons.camera_alt_outlined, iconColor: const Color(0xFFC13584),
                    title: trId('with_photos_videos'),
                    subtitle: trId('posted_to_instagram_thread')),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Guidelines
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trId('community_guidelines'),
                    style: TextStyle(fontWeight: FontWeight.w800, color: context.cText)),
                SizedBox(height: 8),
                for (final g in [
                  trId('be_respectful_and_positive'),
                  trId('no_hate_speech_or_bullying'),
                  trId('no_spam_or_irrelevant_content'),
                  trId('keep_our_community_clean_and_safe'),
                ])
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(Icons.check, size: 15, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(child: Text(g, style: TextStyle(fontSize: 12.5, color: context.cText))),
                    ]),
                  ),
              ],
            ),
          ),
          SizedBox(height: 18),

          // Recent hashtags
          if (_recentTags.isNotEmpty) ...[
            Text(trId('recent_hashtags'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.cText)),
            SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _recentTags.map((t) => GestureDetector(
                onTap: () => _appendTag(t),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: context.cSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.cBorder),
                  ),
                  child: Text(t, style: TextStyle(fontSize: 12.5,
                      fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              )).toList(),
            ),
            SizedBox(height: 24),
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
        label: Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
          padding: EdgeInsets.symmetric(vertical: 14),
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
        SizedBox(width: 12),
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
      padding: EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 6),
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
