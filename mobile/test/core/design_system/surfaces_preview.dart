import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/design_system/surfaces/glass_card.dart';
import 'package:fyc_connect/core/design_system/surfaces/mesh_backdrop.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/service_locator.dart';

/// A look at the new surfaces before they go anywhere near Home.
///
///     flutter test test/core/design_system/surfaces_preview.dart
Future<void> _shoot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 400));
  final b = find.byType(RepaintBoundary).evaluate().first.renderObject!
      as RenderRepaintBoundary;
  final img = await b.toImage(pixelRatio: 2.0);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  Directory('build/ui_shots').createSync(recursive: true);
  File('build/ui_shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');
    final f = FontLoader('Plus Jakarta Sans');
    for (final w in ['400', '600', '700', '800']) {
      f.addFont(File('assets/fonts/PlusJakartaSans-$w.ttf')
          .readAsBytes().then((b) => b.buffer.asByteData()));
    }
    await f.load();
  });

  testWidgets('surfaces', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 860));
    addTearDown(() => t.binding.setSurfaceSize(null));

    const tiles = [
      ('Blood', Color(0xFFE0245E), Icons.water_drop_rounded),
      ('Sports', Color(0xFFF59E0B), Icons.sports_cricket_rounded),
      ('Work', Color(0xFF0E7C66), Icons.handyman_rounded),
      ('Report', Color(0xFF8B5CF6), Icons.campaign_rounded),
      ('Events', Color(0xFF3B82F6), Icons.event_rounded),
      ('Feed', Color(0xFF14B8A6), Icons.dynamic_feed_rounded),
      ('Green', Color(0xFF22C55E), Icons.eco_rounded),
      ('More', Color(0xFF64748B), Icons.grid_view_rounded),
    ];

    await t.pumpWidget(MaterialApp(
      theme: AppTheme.darkFor('en'),
      home: RepaintBoundary(
        child: MeshBackdrop(
          colors: const [
            Color(0xFF0E7C66), Color(0xFF1E3A8A),
            Color(0xFF7C2D6B), Color(0xFFF59E0B),
          ],
          scroll: 0,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('NOW',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12,
                            fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                    const SizedBox(height: 8),
                    ScrimHero(
                      tint: const Color(0xFFF59E0B),
                      height: 175,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('● LIVE',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2)),
                          SizedBox(height: 6),
                          Text('FYC League — Semi Final',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 22,
                                  fontWeight: FontWeight.w800, height: 1.1)),
                          SizedBox(height: 4),
                          Text('Vadasery 128/4 · 14.2 overs',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('EVERYTHING',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12,
                            fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                    const SizedBox(height: 8),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.82,
                      children: [
                        for (final (label, tint, icon) in tiles)
                          GlassCard(
                            tint: tint,
                            onTap: () {},
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, color: Colors.white, size: 26),
                                const SizedBox(height: 6),
                                Text(label,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await _shoot(t, 'surfaces_preview');
  });
}
