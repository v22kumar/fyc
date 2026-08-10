// Photographs the Serve/Help hub — the page reviewed and upgraded in the UI
// pass. Run one test at a time (flutter test hangs at exit here).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/features/serve/presentation/screens/serve_hub_screen.dart';
import 'package:fyc_connect/service_locator.dart';

const _shotKey = Key('shot-boundary');

Future<void> _shoot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 300));
  final boundary = find.byKey(_shotKey).evaluate().first.renderObject!
      as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('build/ui_shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  debugPrint('WROTE ${dir.path}/$name.png');
}

Future<void> _pump(WidgetTester t, {required String lang, required bool dark}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);
  await storage.saveLang(lang);
  if (sl.isRegistered<LocalStorage>()) sl.unregister<LocalStorage>();
  sl.registerSingleton<LocalStorage>(storage);

  await t.binding.setSurfaceSize(const Size(390, 1000));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(MaterialApp(
    theme: dark ? AppTheme.darkFor(lang) : AppTheme.lightFor(lang),
    builder: (_, child) => RepaintBoundary(key: _shotKey, child: child),
    home: const ServeHubScreen(),
  ));
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final (family, path) in [
      ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans-400.ttf'),
      ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans-700.ttf'),
      ('Noto Sans Tamil', 'assets/fonts/NotoSansTamil-400.ttf'),
    ]) {
      final f = File(path);
      if (!f.existsSync()) continue;
      final loader = FontLoader(family)
        ..addFont(f.readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
    final icons = File(
        '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(icons.readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
  });

  testWidgets('62 · serve hub, dark', (t) async {
    await _pump(t, lang: 'en', dark: true);
    await _shoot(t, '62_serve_dark');
  });

  testWidgets('63 · serve hub, light Tamil', (t) async {
    await _pump(t, lang: 'ta', dark: false);
    await _shoot(t, '63_serve_light_ta');
  });
}
