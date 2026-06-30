import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  bool _hasScanned = false;
  bool _torchOn = false;

  String get _lang => sl<LocalStorage>().getLang();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    final raw = barcode.rawValue!;
    setState(() => _hasScanned = true);
    _controller.stop();
    _handleScannedPayload(raw);
  }

  void _handleScannedPayload(String payload) {
    final isTa = _lang == 'ta';

    // FYC QR payloads:
    // Membership: "FYC:{membership_number}:{user_id}"
    // Event check-in: "FYC-EVENT:{event_id}:{event_title}"
    if (payload.startsWith('FYC-EVENT:')) {
      final parts = payload.split(':');
      final eventId = parts.length > 1 ? parts[1] : 'unknown';
      final eventTitle = parts.length > 2 ? parts.sublist(2).join(':') : '';
      _showResultDialog(
        success: true,
        title: tr(en: 'Event Check-In', ta: 'நிகழ்வு சரிபார்ப்பு', hi: 'इवेंट चेक-इन', ml: 'ഇവന്റ് ചെക്ക്-ഇൻ'),
        message: tr(
          en: 'Successfully checked in!\n\n$eventTitle',
          ta: 'நிகழ்வில் வெற்றிகரமாக பதிவு செய்யப்பட்டது!\n\n$eventTitle',
          hi: 'सफलतापूर्वक चेक-इन हो गया!\n\n$eventTitle',
          ml: 'വിജയകരമായി ചെക്ക്-ഇൻ ചെയ്തു!\n\n$eventTitle',
        ),
        detail: 'ID: $eventId',
      );
    } else if (payload.startsWith('FYC:')) {
      final parts = payload.split(':');
      final membershipNumber = parts.length > 1 ? parts[1] : 'unknown';
      _showResultDialog(
        success: true,
        title: tr(en: 'Membership Verified', ta: 'உறுப்பினர் சரிபார்ப்பு', hi: 'सदस्यता सत्यापित', ml: 'അംഗത്വം പരിശോധിച്ചു'),
        message: tr(
          en: 'Valid FYC Membership Card',
          ta: 'செல்லுபடியான FYC உறுப்பினர் அட்டை',
          hi: 'वैध FYC सदस्यता कार्ड',
          ml: 'സാധുവായ FYC അംഗത്വ കാർഡ്',
        ),
        detail: membershipNumber,
      );
    } else {
      _showResultDialog(
        success: false,
        title: tr(en: 'Unknown QR Code', ta: 'அறியப்படாத குறியீடு', hi: 'अज्ञात QR कोड', ml: 'അജ്ഞാത QR കോഡ്'),
        message: tr(
          en: 'This QR code was not issued by the FYC system.',
          ta: 'இந்த QR குறியீடு FYC அமைப்பால் உருவாக்கப்படவில்லை.',
          hi: 'यह QR कोड FYC सिस्टम द्वारा जारी नहीं किया गया था।',
          ml: 'ഈ QR കോഡ് FYC സിസ്റ്റം നൽകിയതല്ല.',
        ),
        detail: payload.length > 60 ? '${payload.substring(0, 60)}…' : payload,
      );
    }
  }

  void _showResultDialog({
    required bool success,
    required String title,
    required String message,
    required String detail,
  }) {
    final isTa = _lang == 'ta';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              success ? Icons.verified : Icons.error_outline,
              color: success ? AppColors.primary : AppColors.accent,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                detail,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _hasScanned = false);
              _controller.start();
            },
            child: Text(tr(en: 'Scan Again', ta: 'மீண்டும் ஸ்கேன்', hi: 'फिर से स्कैन करें', ml: 'വീണ്ടും സ്കാൻ ചെയ്യുക')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(tr(en: 'Done', ta: 'முடிந்தது', hi: 'पूर्ण', ml: 'പൂർത്തിയായി')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTa = _lang == 'ta';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          tr(en: 'Scan QR Code', ta: 'QR ஸ்கேன்', hi: 'QR कोड स्कैन करें', ml: 'QR കോഡ് സ്കാൻ ചെയ്യുക'),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_off : Icons.flash_on,
              color: Colors.white,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
            tooltip: tr(en: 'Torch', ta: 'ஒளி', hi: 'टॉर्च', ml: 'ടോർച്ച്'),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Scan frame overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Corner decorations
                  ..._buildCorners(),
                ],
              ),
            ),
          ),
          // Bottom hint
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              tr(
                en: 'Place the FYC QR code inside the frame',
                ta: 'FYC QR குறியீட்டை சதுரத்தில் வைக்கவும்',
                hi: 'FYC QR कोड को फ्रेम के अंदर रखें',
                ml: 'FYC QR കോഡ് ഫ്രെയിമിനുള്ളിൽ വയ്ക്കുക',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                backgroundColor: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 20.0;
    const thickness = 4.0;
    const color = Color(0xFFFBBF24); // gold
    return [
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: size,
          height: thickness,
          color: color,
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: thickness,
          height: size,
          color: color,
        ),
      ),
      // Top-right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: size,
          height: thickness,
          color: color,
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: thickness,
          height: size,
          color: color,
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: size,
          height: thickness,
          color: color,
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: thickness,
          height: size,
          color: color,
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: size,
          height: thickness,
          color: color,
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: thickness,
          height: size,
          color: color,
        ),
      ),
    ];
  }
}
