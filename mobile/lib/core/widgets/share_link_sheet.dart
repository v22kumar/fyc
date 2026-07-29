import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/api_constants.dart';
import '../l10n/tr.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';

/// Bottom sheet showing a short, typeable share link and a scannable QR for an
/// event or tournament, so an admin can display, copy, or forward it — or point
/// a phone camera at the screen to print it onto a notice/banner.
///
/// [path] is the site-relative short path, e.g. "/t/K7P2" or "/e/K7P2".
Future<void> showShareLinkSheet(
  BuildContext context, {
  required String path,
  required String title,
}) {
  final url = '${ApiConstants.webBaseUrl}$path';
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: QrImageView(
                data: url,
                size: 200,
                version: QrVersions.auto,
                backgroundColor: AppColors.background,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F172A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            SizedBox(height: 14),
            SelectableText(
              url,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF065F46)),
            ),
            SizedBox(height: 6),
            Text(
              trId('scan_to_open'),
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary.withOpacity(0.6)),
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.copy, size: 18),
                    label: Text(trId('copy_link')),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(ctx);
                      await Clipboard.setData(ClipboardData(text: url));
                      messenger.showSnackBar(
                        SnackBar(content: Text(trId('link_copied')), duration: const Duration(seconds: 2)),
                      );
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: Icon(Icons.share, size: 18),
                    label: Text(trId('share_link')),
                    onPressed: () => Share.share(url),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
