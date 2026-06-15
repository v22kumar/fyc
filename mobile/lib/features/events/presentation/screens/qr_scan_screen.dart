import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

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
        title: isTa ? 'நிகழ்வு சரிபார்ப்பு' : 'Event Check-In',
        message: isTa
            ? 'நிகழ்வில் வெற்றிகரமாக பதிவு செய்யப்பட்டது!\n\n$eventTitle'
            : 'Successfully checked in!\n\n$eventTitle',
        detail: 'ID: $eventId',
      );
    } else if (payload.startsWith('FYC:')) {
      final parts = payload.split(':');
      final membershipNumber = parts.length > 1 ? parts[1] : 'unknown';
      _showResultDialog(
        success: true,
        title: isTa ? 'உறுப்பினர் சரிபார்ப்பு' : 'Membership Verified',
        message: isTa
            ? 'செல்லுபடியான FYC உறுப்பினர் அட்டை'
            : 'Valid FYC Membership Card',
        detail: membershipNumber,
      );
    } else {
      _showResultDialog(
        success: false,
        title: isTa ? 'அறியப்படாத குறியீடு' : 'Unknown QR Code',
        message: isTa
            ? 'இந்த QR குறியீடு FYC அமைப்பால் உருவாக்கப்படவில்லை.'
            : 'This QR code was not issued by the FYC system.',
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
            child: Text(isTa ? 'மீண்டும் ஸ்கேன்' : 'Scan Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(isTa ? 'முடிந்தது' : 'Done'),
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
          isTa ? 'QR ஸ்கேன்' : 'Scan QR Code',
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
            tooltip: isTa ? 'ஒளி' : 'Torch',
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
              isTa
                  ? 'FYC QR குறியீட்டை சதுரத்தில் வைக்கவும்'
                  : 'Place the FYC QR code inside the frame',
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
