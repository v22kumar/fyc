import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../storage/local_storage.dart';
import '../theme/app_theme.dart';
import '../../service_locator.dart';

/// Shows a one-tap "update available" dialog. Tapping Update opens the APK
/// download (Android's download manager handles it; the user taps the file to
/// install). Non-mandatory updates can be dismissed with "Later".
class UpdateDialog {
  static const _skipKey = 'fyc_skipped_update_code';

  /// Call after the home screen is mounted. Best-effort and non-blocking.
  static Future<void> maybePrompt(BuildContext context) async {
    final update = await UpdateService.check();
    if (update == null || !context.mounted) return;

    final storage = sl<LocalStorage>();
    // Respect a previous "Later" for this exact version (mandatory always shows).
    if (!update.mandatory) {
      final skipped = int.tryParse(storage.getString(_skipKey) ?? '') ?? 0;
      if (skipped >= update.latestVersionCode) return;
    }

    final ta = storage.getLang() == 'ta';
    await showDialog(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (ctx) => PopScope(
        canPop: !update.mandatory,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ta ? 'புதிய பதிப்பு கிடைக்கிறது' : 'Update available',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ta
                    ? 'FYC Connect இன் புதிய பதிப்பு ${update.latestVersionName} தயாராக உள்ளது.'
                    : 'A newer version of FYC Connect (${update.latestVersionName}) is ready.',
                style: const TextStyle(fontSize: 14),
              ),
              if (update.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(ta ? 'புதியவை:' : "What's new:",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(update.notes, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
          actions: [
            if (!update.mandatory)
              TextButton(
                onPressed: () {
                  storage.saveString(_skipKey, update.latestVersionCode.toString());
                  Navigator.of(ctx).pop();
                },
                child: Text(ta ? 'பிறகு' : 'Later'),
              ),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(update.apkUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (ctx.mounted && !update.mandatory) Navigator.of(ctx).pop();
              },
              icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
              label: Text(ta ? 'புதுப்பி' : 'Update Now',
                  style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
