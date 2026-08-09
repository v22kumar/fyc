import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/design_system/shell/sos_sheet.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/features/settings/presentation/screens/safety_settings_screen.dart';
import 'package:fyc_connect/service_locator.dart';

/// Photographs the SOS surfaces so a human can look at what a member in an
/// emergency is actually handed.
///
/// A camera, not an assertion suite — deliberately named without `_test` so
/// `flutter test` never collects it. Run it on purpose:
///
///     flutter test test/core/safety/sos_render_harness.dart
/// The boundary the shot is taken from.
///
/// Keyed rather than "the first RepaintBoundary in the tree", because a modal
/// sheet lives in the Navigator's overlay — *above* `home` — so a boundary
/// placed at `home` photographs the empty page underneath it. That is exactly
/// the blank grey rectangle this harness produced on its first run.
const _shotKey = Key('shot-boundary');

Future<void> _shoot(WidgetTester tester, String name) async {
  // Pumped in steps rather than once: a modal route has to build, then run its
  // entrance animation, and anything reading SharedPreferences resolves a
  // frame or two later still. One 400ms pump photographed the empty page.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final el = find.byKey(_shotKey).evaluate().first;
  final boundary = el.renderObject! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = Directory('build/ui_shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _phone(WidgetTester t, Widget w) async {
  await t.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(w);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      // A member who has done the setup — the best case, not the empty one.
      'sos_trusted_contacts': '["+91 98400 11111","+91 94431 22222"]',
    });
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');

    for (final (family, file) in [
      ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans-400.ttf'),
      ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans-700.ttf'),
      ('Noto Sans Tamil', 'assets/fonts/NotoSansTamil-400.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(File(file).readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
    final iconFile = File(
        '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(iconFile.readAsBytes().then((b) => b.buffer.asByteData()));
      await icons.load();
    }
  });

  testWidgets('sos sheet — as a member in trouble sees it', (t) async {
    await _phone(
      t,
      MaterialApp(
        theme: AppTheme.lightFor('en'),
        // Wraps the Navigator, so the sheet in its overlay is inside the shot.
        builder: (_, child) => RepaintBoundary(key: _shotKey, child: child),
        home: const Scaffold(
          backgroundColor: Color(0xFFEFEFEF),
          body: _SheetProbe(),
        ),
      ),
    );
    await _shoot(t, '20_sos_sheet_today');
  });

  testWidgets('safety settings — where contacts are set up', (t) async {
    await _phone(
      t,
      MaterialApp(
        theme: AppTheme.lightFor('en'),
        builder: (_, child) => RepaintBoundary(key: _shotKey, child: child),
        home: const SafetySettingsScreen(),
      ),
    );
    await _shoot(t, '21_safety_settings_today');
  });

  testWidgets('safety settings — in Tamil', (t) async {
    await sl<LocalStorage>().saveLang('ta');
    addTearDown(() => sl<LocalStorage>().saveLang('en'));
    await _phone(
      t,
      MaterialApp(
        theme: AppTheme.lightFor('ta'),
        builder: (_, child) => RepaintBoundary(key: _shotKey, child: child),
        home: const SafetySettingsScreen(),
      ),
    );
    await _shoot(t, '22_safety_settings_tamil');
  });
}

/// Opens the real sheet on the first frame so it can be photographed in place.
class _SheetProbe extends StatefulWidget {
  const _SheetProbe();
  @override
  State<_SheetProbe> createState() => _SheetProbeState();
}

class _SheetProbeState extends State<_SheetProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => showSosSheet(context, memberName: 'Arun Kumar'));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
