import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/l10n/tr.dart';
import '../../domain/civic_categories.dart';
import '../../../../core/location/member_location.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';

/// Report something broken, in three steps and one language.
///
/// The screen this replaces asked for two prose descriptions — `description_ta`
/// **and** `description_en`, both required — before it would accept anything.
/// Somebody standing in front of an overflowing drain had to compose the
/// complaint in Tamil and then again in English. It also opened on a form, with
/// the camera four scrolls down.
///
/// The order here is the argument: **photo, category, one sentence.** The photo
/// is the report — an officer acts on a picture of a broken thing far sooner
/// than on a paragraph — so the camera opens on entry and everything else
/// follows it. Location is taken silently from a fix the phone already has.
///
/// Kept as a separate screen from `SubmitIssueScreen` rather than replacing it
/// in place: the old one posts to the old endpoint, which still works, and this
/// can be put in front of people without a flag day.
class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _words = TextEditingController();
  final _scroll = ScrollController();

  Uint8List? _photo;
  String? _photoUrl;
  bool _uploading = false;
  String? _kind;
  double? _lat;
  double? _lng;
  bool _sending = false;

  /// One question, asked once. It steers what the next screen suggests and
  /// never blocks anything: somebody who wants to ring about a serious problem
  /// still can.
  bool _serious = false;

  @override
  void initState() {
    super.initState();
    // The camera is the first thing that happens, not the fourth. Scheduled
    // after the first frame so the screen is behind the camera when it closes
    // — otherwise a cancelled capture lands on a blank route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _takePhoto();
      _findLocation();
    });
  }

  @override
  void dispose() {
    _words.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// A position, only if the phone already has one.
  ///
  /// Never prompts here. Somebody halfway through reporting a broken drain did
  /// not come to answer a question about location permissions, and they will be
  /// asked properly somewhere they are browsing.
  Future<void> _findLocation() async {
    final pos = await MemberLocation.ifAlreadyAllowed();
    if (!mounted || pos == null) return;
    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
    });
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _photo = bytes;
        _uploading = true;
      });
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'issue.jpg'),
      });
      final resp = await sl<ApiClient>().dio.post('/api/v1/media/upload', data: form);
      if (!mounted) return;
      setState(() => _photoUrl = resp.data['url'] as String?);
    } catch (_) {
      // A failed upload must not take the photo away — they can send again.
      if (mounted) setState(() => _photoUrl = null);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _whatIsMissing() {
    if (_photoUrl == null) return trId('report_photo_needed');
    if (_kind == null) return trId('report_category_needed');
    if (_words.text.trim().isEmpty) return trId('report_words_needed');
    return null;
  }

  Future<void> _send() async {
    final missing = _whatIsMissing();
    if (missing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(missing), backgroundColor: AppColors.accent),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final created = await sl<ApiClient>().dio.post('/api/v1/issues/v2', data: {
        'category': _kind,
        // How bad it is, which decides what the next screen suggests: routine
        // problems go to the phone, serious ones to a letter, because a call
        // leaves no evidence and a letter is dated and quotable.
        'severity': _serious ? 'SERIOUS' : 'ROUTINE',
        'description': _words.text.trim(),
        // Which language the words are actually in, so nothing downstream is
        // passed off as a translation that never happened.
        'description_lang': sl<LocalStorage>().getLang(),
        'latitude': _lat ?? 0,
        'longitude': _lng ?? 0,
        'photo_url': _photoUrl,
      });
      if (!mounted) return;
      final id = (created.data is Map) ? created.data['id'] as String? : null;
      await _showSent(complaintId: id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trId('action_failed_try_again')),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  /// What happens next, said plainly.
  ///
  /// "Submitted" and silence is what teaches people not to bother a second
  /// time. This says who looks at it and that they will be able to see where it
  /// goes.
  Future<void> _showSent({String? complaintId}) async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      backgroundColor: context.cSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
              const SizedBox(height: 14),
              Text(
                trId('report_sent_title'),
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: context.cText),
              ),
              const SizedBox(height: 8),
              Text(
                trId('report_sent_body'),
                style: TextStyle(
                  fontSize: 15, height: 1.45, color: context.cTextSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    if (!mounted) return;
                    // Straight into the Complaint Box for this report, where
                    // the three routes live. "Submitted" and a list is how a
                    // report becomes a thing nobody does anything about.
                    if (complaintId != null) {
                      context.push('/complaints/$complaintId?category=$_kind');
                    } else {
                      context.go('/issues/track');
                    }
                  },
                  child: Text(complaintId != null
                      ? trId('what_next')
                      : trId('my_reports')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _whatIsMissing() == null;
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(title: Text(trId('report_an_issue_2'))),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _EmergencyNote(),
          const SizedBox(height: 14),
          _StepLabel(1, trId('report_take_photo')),
          const SizedBox(height: 8),
          _PhotoBox(
            photo: _photo,
            uploading: _uploading,
            onTap: _takePhoto,
          ),
          const SizedBox(height: 6),
          Text(
            trId('report_photo_is_the_report'),
            style: TextStyle(fontSize: 13, color: context.cTextSecondary, height: 1.4),
          ),
          const SizedBox(height: 22),
          _StepLabel(2, trId('report_what_is_it')),
          const SizedBox(height: 10),
          _KindGrid(
            selected: _kind,
            onSelect: (code) => setState(() => _kind = code),
          ),
          const SizedBox(height: 14),
          // Asked plainly, because the honest version of this question is
          // "should this leave a paper trail" and most people know the answer
          // for their own problem better than any rule would.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _serious,
            onChanged: (v) => setState(() => _serious = v),
            title: Text(trId('is_this_serious'),
                style: TextStyle(fontWeight: FontWeight.w600, color: context.cText)),
            subtitle: Text(trId('is_this_serious_help'),
                style: TextStyle(fontSize: 13, color: context.cTextSecondary)),
          ),
          const SizedBox(height: 22),
          _StepLabel(3, trId('report_say_it_once')),
          const SizedBox(height: 10),
          TextField(
            controller: _words,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: trId('report_describe_hint'),
              filled: true,
              fillColor: context.cSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.cBorder),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _LocationLine(has: _lat != null && _lng != null),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: (_sending || !ready) ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    trId('report_send'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Anything happening right now belongs on a phone call, not in a review queue.
class _EmergencyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trId('report_emergency_hint'),
              style: TextStyle(fontSize: 12.5, height: 1.35, color: context.cText),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final int n;
  final String text;
  const _StepLabel(this.n, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22, height: 22, alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Text('$n',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        // Flexible, not fixed: these labels are four times longer in Malayalam
        // than in English and would otherwise overflow the row.
        Flexible(
          child: Text(text,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: context.cText)),
        ),
      ],
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final Uint8List? photo;
  final bool uploading;
  final VoidCallback onTap;
  const _PhotoBox({required this.photo, required this.uploading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        height: 190,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cBorder),
        ),
        child: photo == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_rounded, size: 38, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(trId('report_take_photo'),
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: context.cText)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(photo!, fit: BoxFit.cover),
                  if (uploading)
                    Container(
                      color: Colors.black38,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(color: Colors.white),
                    ),
                  Positioned(
                    right: 10, bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(trId('report_retake'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _KindGrid extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  const _KindGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder, not MediaQuery. MediaQuery reports the window, and this
    // grid lives inside a padded list — on a tablet, on the web, or in the
    // screenshot harness (which renders a phone-sized box inside a desktop
    // window) a MediaQuery-derived width made every tile full-bleed and stacked
    // all fourteen in a single column. The constraints handed down here are the
    // space the tiles actually have.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        // Two columns on a phone; more only once there is genuinely room, so a
        // wide window does not stretch fourteen tiles into unreadable bands.
        final columns = constraints.maxWidth > 560 ? 3 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final kind in CivicCategory.all)
              _KindTile(
                kind: kind,
                width: width,
                selected: selected == kind.code,
                onTap: () => onSelect(kind.code),
              ),
          ],
        );
      },
    );
  }
}

class _KindTile extends StatelessWidget {
  final CivicCategory kind;
  final double width;
  final bool selected;
  final VoidCallback onTap;
  const _KindTile({
    required this.kind,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('kind-${kind.code}'),
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.10) : context.cSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : context.cBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(kind.icon,
                size: 20,
                color: selected ? AppColors.primary : context.cTextSecondary),
            const SizedBox(width: 10),
            // The label wraps rather than being cut off: these words are far
            // longer in Tamil and Malayalam than the English they were sized on.
            Expanded(
              child: Text(
                trId(kind.labelId),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.primary : context.cText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationLine extends StatelessWidget {
  final bool has;
  const _LocationLine({required this.has});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(has ? Icons.place_rounded : Icons.location_off_outlined,
            size: 16,
            color: has ? AppColors.success : context.cTextSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            trId(has ? 'report_location_on' : 'report_location_off'),
            style: TextStyle(
                fontSize: 12.5,
                color: has ? AppColors.success : context.cTextSecondary),
          ),
        ),
      ],
    );
  }
}
