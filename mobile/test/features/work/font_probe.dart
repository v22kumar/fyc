import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/service_locator.dart';

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

  testWidgets('probe', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightFor('en'),
      home: RepaintBoundary(
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('A: plain default'),
                const Text('B: w400',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w400)),
                const Text('C: w700 bold',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ActionChip(label: const Text('D: chip label'), onPressed: () {}),
                const SizedBox(height: 8),
                const Chip(label: Text('E: plain Chip')),
              ],
            ),
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 200));
    final b = find.byType(RepaintBoundary).evaluate().first.renderObject!
        as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2.0);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    Directory('build/ui_shots').createSync(recursive: true);
    File('build/ui_shots/font_probe.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
