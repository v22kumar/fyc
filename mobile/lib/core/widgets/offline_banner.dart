import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Shows a persistent red banner when the device has no internet.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _offline = false;
  late StreamSubscription<List<ConnectivityResult>> _sub;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final nowOffline = results.every((r) => r == ConnectivityResult.none);
      if (mounted && nowOffline != _offline) setState(() => _offline = nowOffline);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: const Color(0xFFDC2626),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 14),
            SizedBox(width: 8),
            Text('No internet connection', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
