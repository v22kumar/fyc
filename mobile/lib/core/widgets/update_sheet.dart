import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../services/update_installer.dart';
import '../storage/local_storage.dart';
import '../theme/app_theme.dart';
import '../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

/// Premium in-app update experience: a modal sheet that downloads the APK with
/// a live progress bar and opens the installer in one tap. Mandatory updates
/// can't be dismissed; optional ones can be deferred.
class UpdateSheet {
  static const _skipKey = 'fyc_skipped_update_code';

  /// Auto-prompt: checks the backend and shows the sheet if a newer build
  /// exists. Respects a prior "Later" for optional updates.
  static Future<void> maybeShow(BuildContext context) async {
    final update = await UpdateService.check();
    if (update == null || !context.mounted) return;

    final storage = sl<LocalStorage>();
    if (!update.mandatory) {
      final skipped = int.tryParse(storage.getString(_skipKey) ?? '') ?? 0;
      if (skipped >= update.latestVersionCode) return;
    }
    if (!context.mounted) return;
    await show(context, update);
  }

  /// Show the sheet for a known update (used by the manual "Check for Updates").
  static Future<void> show(BuildContext context, UpdateInfo update) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !update.mandatory,
      enableDrag: !update.mandatory,
      backgroundColor: Colors.transparent,
      builder: (_) => PopScope(
        canPop: !update.mandatory,
        child: _UpdateSheetBody(update: update),
      ),
    );
  }
}

enum _Phase { idle, downloading, installing, error }

class _UpdateSheetBody extends StatefulWidget {
  final UpdateInfo update;
  const _UpdateSheetBody({required this.update});

  @override
  State<_UpdateSheetBody> createState() => _UpdateSheetBodyState();
}

class _UpdateSheetBodyState extends State<_UpdateSheetBody> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;

  bool get _ta => sl<LocalStorage>().getLang() == 'ta';

  Future<void> _startUpdate() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
    });
    try {
      await UpdateInstaller.downloadAndInstall(
        widget.update.apkUrl,
        widget.update.latestVersionCode,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p.clamp(0.0, 1.0));
        },
      );
      if (mounted) setState(() => _phase = _Phase.installing);
      // The OS installer is now in the foreground; close the sheet so the user
      // returns to a clean app once they confirm/deny the install.
      if (mounted && !widget.update.mandatory) Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _fallbackBrowser() async {
    final uri = Uri.parse(widget.update.apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _later() {
    sl<LocalStorage>()
        .saveString(UpdateSheet._skipKey, '${widget.update.latestVersionCode}');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final ta = _ta;
    final u = widget.update;
    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 10,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!u.mandatory)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                    color: context.cBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            )
          else
            const SizedBox(height: 14),
          // Icon + title
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.gradientPrimary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Image.asset('assets/images/fyc_logo_icon.png',
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.system_update, color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(en: 'Update Available', ta: 'புதிய பதிப்பு தயாராக உள்ளது', hi: 'अपडेट उपलब्ध है', ml: 'അപ്ഡേറ്റ് ലഭ്യമാണ്'),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.cText)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('v${u.latestVersionName}',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            u.notes.trim().isNotEmpty
                ? u.notes
                : tr(
                    en: 'Get the latest features and improvements with this update.',
                    ta: 'சமீபத்திய அம்சங்கள் மற்றும் சீர்திருத்தங்களைப் பெற புதுப்பிக்கவும்.',
                    hi: 'इस अपडेट के साथ नवीनतम सुविधाएं और सुधार पाएं।',
                    ml: 'ഈ അപ്ഡേറ്റിലൂടെ ഏറ്റവും പുതിയ സവിശേഷതകളും മെച്ചപ്പെടുത്തലുകളും നേടൂ.'),
            style: TextStyle(
                fontSize: 13.5, height: 1.4, color: context.cTextSecondary),
          ),
          const SizedBox(height: 20),
          _buildAction(context, ta),
          if (u.mandatory) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                tr(
                    en: 'This update is required to continue',
                    ta: 'தொடர இந்த புதுப்பிப்பு அவசியம்',
                    hi: 'जारी रखने के लिए यह अपडेट आवश्यक है',
                    ml: 'തുടരാൻ ഈ അപ്ഡേറ്റ് ആവശ്യമാണ്'),
                style: TextStyle(fontSize: 11.5, color: context.cTextSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, bool ta) {
    switch (_phase) {
      case _Phase.downloading:
        final pct = (_progress * 100).clamp(0, 100).toStringAsFixed(0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 10,
                backgroundColor: context.cBorder,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(tr(en: 'Downloading… $pct%', ta: 'பதிவிறக்குகிறது… $pct%', hi: 'डाउनलोड हो रहा है… $pct%', ml: 'ഡൗൺലോഡ് ചെയ്യുന്നു… $pct%'),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.cTextSecondary)),
          ],
        );
      case _Phase.installing:
        return Row(
          children: [
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary)),
            const SizedBox(width: 12),
            Text(tr(en: 'Opening installer…', ta: 'நிறுவலைத் திறக்கிறது…', hi: 'इंस्टॉलर खोला जा रहा है…', ml: 'ഇൻസ്റ്റാളർ തുറക്കുന്നു…'),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.cText)),
          ],
        );
      case _Phase.error:
        return Column(
          children: [
            Text(
              tr(
                  en: "Download failed. Try via your browser instead.",
                  ta: 'பதிவிறக்கம் தோல்வியடைந்தது. உலாவியில் முயற்சிக்கவும்.',
                  hi: 'डाउनलोड विफल रहा। इसके बजाय अपने ब्राउज़र से प्रयास करें।',
                  ml: 'ഡൗൺലോഡ് പരാജയപ്പെട്ടു. പകരം നിങ്ങളുടെ ബ്രൗസർ വഴി ശ്രമിക്കുക.'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.accent),
            ),
            const SizedBox(height: 10),
            _primaryButton(
                tr(en: 'Download in browser', ta: 'உலாவியில் பதிவிறக்கு', hi: 'ब्राउज़र में डाउनलोड करें', ml: 'ബ്രൗസറിൽ ഡൗൺലോഡ് ചെയ്യുക'),
                _fallbackBrowser),
          ],
        );
      case _Phase.idle:
        return Column(
          children: [
            _primaryButton(tr(en: 'Update Now', ta: 'இப்போது புதுப்பி', hi: 'अभी अपडेट करें', ml: 'ഇപ്പോൾ അപ്ഡേറ്റ് ചെയ്യുക'), _startUpdate),
            if (!widget.update.mandatory) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: _later,
                child: Text(tr(en: 'Later', ta: 'பிறகு', hi: 'बाद में', ml: 'പിന്നീട്'),
                    style: TextStyle(color: context.cTextSecondary)),
              ),
            ],
          ],
        );
    }
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppTheme.gradientPrimary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 19),
          label: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}
