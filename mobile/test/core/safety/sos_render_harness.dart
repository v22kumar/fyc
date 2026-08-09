import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/features/safety/presentation/bloc/responder_bloc.dart';
import 'package:fyc_connect/features/safety/presentation/bloc/safety_setup_bloc.dart';
import 'package:fyc_connect/features/safety/presentation/bloc/sos_bloc.dart';
import 'package:fyc_connect/features/safety/presentation/screens/responder_alert_screen.dart';
import 'package:fyc_connect/features/safety/presentation/screens/safety_setup_screen.dart';
import 'package:fyc_connect/features/safety/presentation/screens/sos_live_screen.dart';
import 'package:fyc_connect/features/safety/presentation/screens/sos_trigger_screen.dart';
import 'package:fyc_connect/service_locator.dart';

import 'fake_safety_repository.dart';

/// Photographs the SOS surfaces so a human can look at what a member in an
/// emergency is actually handed.
///
/// A camera, not an assertion suite — named without `_test` so `flutter test`
/// never collects it. Run it deliberately:
///
///     flutter test test/core/safety/sos_render_harness.dart
///
/// Output lands in build/ui_shots/.

/// Keyed rather than "the first RepaintBoundary in the tree": a modal sheet
/// lives in the Navigator's overlay, *above* `home`, so a boundary placed at
/// `home` photographs the empty page underneath it. That is exactly the blank
/// grey rectangle this harness produced on its first run.
const _shotKey = Key('shot-boundary');

Future<void> _shoot(WidgetTester tester, String name) async {
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

Widget _app(Widget home, {String lang = 'en'}) => MaterialApp(
      theme: AppTheme.lightFor(lang),
      builder: (_, child) => RepaintBoundary(key: _shotKey, child: child),
      home: home,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('trigger — ready', (t) async {
    final repo = FakeSafetyRepository(contacts: 2, onRoster: true);
    await _phone(
      t,
      _app(BlocProvider(
        create: (_) => SosBloc(repo, probe: fakeProbe(accuracyM: 12)),
        child: const SosTriggerScreen(),
      )),
    );
    await _shoot(t, '30_sos_trigger_ready');
  });

  testWidgets('trigger — nothing set up', (t) async {
    final repo = FakeSafetyRepository(contacts: 0);
    await _phone(
      t,
      _app(BlocProvider(
        create: (_) => SosBloc(repo, probe: fakeProbe(fails: true)),
        child: const SosTriggerScreen(),
      )),
    );
    await _shoot(t, '31_sos_trigger_unset');
  });

  testWidgets('live — nobody has answered', (t) async {
    final repo = FakeSafetyRepository(incident: incidentNobodyYet);
    final bloc = SosBloc(repo, probe: fakeProbe(accuracyM: 12))
      ..add(const SosRaised());
    await _phone(t, _app(BlocProvider.value(value: bloc, child: const SosLiveScreen())));
    await _shoot(t, '32_sos_live_silent');
  });

  testWidgets('live — two coming', (t) async {
    final repo = FakeSafetyRepository(incident: incidentTwoComing);
    final bloc = SosBloc(repo, probe: fakeProbe(accuracyM: 12))
      ..add(const SosRaised());
    await _phone(t, _app(BlocProvider.value(value: bloc, child: const SosLiveScreen())));
    await _shoot(t, '33_sos_live_coming');
  });

  testWidgets('responder — asked', (t) async {
    final repo = FakeSafetyRepository();
    await _phone(
      t,
      _app(BlocProvider(
        create: (_) => ResponderBloc(repo),
        child: const ResponderAlertScreen(incidentId: 'i1'),
      )),
    );
    await _shoot(t, '34_responder_asked');
  });

  testWidgets('setup — in Tamil', (t) async {
    await sl<LocalStorage>().saveLang('ta');
    addTearDown(() => sl<LocalStorage>().saveLang('en'));
    final repo = FakeSafetyRepository(contacts: 2, onRoster: true);
    await _phone(
      t,
      _app(
        BlocProvider(
          create: (_) => SafetySetupBloc(repo, probe: fakeProbe(accuracyM: 20)),
          child: const SafetySetupScreen(),
        ),
        lang: 'ta',
      ),
    );
    await _shoot(t, '35_safety_setup_tamil');
  });
}
