import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/network/api_client.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/service_locator.dart';
import 'package:fyc_connect/features/home/presentation/screens/home_screen.dart';

/// Photograph the whole of Home in one image.
///
/// Rendered at phone width and a very tall surface, so the entire scroll is a
/// single picture rather than a set of overlapping fragments — the question
/// being asked is how much is on this screen altogether, and that cannot be
/// answered a viewport at a time.
///
///     flutter test test/features/home/home_capture.dart
Future<void> _shoot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 600));
  final b = find.byType(RepaintBoundary).evaluate().first.renderObject!
      as RenderRepaintBoundary;
  final image = await b.toImage(pixelRatio: 1.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  Directory('build/ui_shots').createSync(recursive: true);
  File('build/ui_shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    if (!sl.isRegistered<ApiClient>()) {
      sl.registerSingleton<ApiClient>(ApiClient(sl<LocalStorage>()));
    }
    await sl<LocalStorage>().saveLang('en');

    final latin = FontLoader('Plus Jakarta Sans');
    for (final w in ['400', '600', '700', '800']) {
      latin.addFont(File('assets/fonts/PlusJakartaSans-$w.ttf')
          .readAsBytes().then((b) => b.buffer.asByteData()));
    }
    await latin.load();
    final tamil = FontLoader('Noto Sans Tamil')
      ..addFont(File('assets/fonts/NotoSansTamil-400.ttf')
          .readAsBytes().then((b) => b.buffer.asByteData()));
    await tamil.load();
  });

  for (final b in [Brightness.dark, Brightness.light]) {
    final name = b == Brightness.dark ? 'dark' : 'light';

    testWidgets('home whole page — $name', (t) async {
      // Phone width, and tall enough that nothing is below the fold.
      await t.binding.setSurfaceSize(const Size(390, 3400));
      addTearDown(() => t.binding.setSurfaceSize(null));

      await t.pumpWidget(MaterialApp(
        theme: b == Brightness.dark
            ? AppTheme.darkFor('en')
            : AppTheme.lightFor('en'),
        home: const RepaintBoundary(child: HomeScreen()),
      ));
      // Network calls fail in here and are expected to; the point is the
      // layout, not the data.
      await t.pump(const Duration(seconds: 1));
      await _shoot(t, 'home_full_$name');
    });
  }
}
