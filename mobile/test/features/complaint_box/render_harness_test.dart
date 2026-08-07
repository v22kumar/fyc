@Tags(['render'])
library;

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
import 'package:fyc_connect/features/complaint_box/domain/entities/complaint_entities.dart';
import 'package:fyc_connect/features/complaint_box/presentation/widgets/complaint_timeline.dart';
import 'package:fyc_connect/features/complaint_box/presentation/widgets/ladder_list.dart';
import 'package:fyc_connect/features/complaint_box/presentation/widgets/send_letter_sheet.dart';

/// Renders the Complaint Box surfaces to PNGs so a human can look at them.
/// Not assertions — a camera. Run with: flutter test --tags render
Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 300));
  final el = find.byType(RepaintBoundary).evaluate().first;
  final boundary = el.renderObject! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('build/ui_shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _frame(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.lightFor("en")
          : AppTheme.darkFor("en"),
      home: RepaintBoundary(
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

final _ladder = CallLadder(
  category: 'STREET_LIGHT',
  placeName: 'Vadasery',
  rungs: const [
    LadderRung(
      position: 1, departmentCode: 'ULB', departmentName: 'Nagercoil Corporation',
      covers: 'your ward', canCall: false, canWrite: false, waitDays: 14,
      designation: 'Ward Councillor',
    ),
    LadderRung(
      position: 2, departmentCode: 'ULB', departmentName: 'Nagercoil Corporation',
      covers: 'your area', canCall: true, canWrite: true, waitDays: 14,
      designation: 'Assistant Engineer — Street Lighting',
      phone: '9443132365', email: 'ae.light@nagercoil.gov.in',
    ),
    LadderRung(
      position: 3, departmentCode: 'ULB', departmentName: 'Nagercoil Corporation',
      covers: 'the local body', canCall: false, canWrite: true, waitDays: 14,
      designation: 'Commissioner', email: 'commr.nagarcoil@tn.gov.in',
    ),
    LadderRung(
      position: 4, departmentCode: 'REV', departmentName: 'Revenue',
      covers: 'the district', canCall: true, canWrite: true, waitDays: 21,
      designation: 'District Collector',
      phone: '04652279090', email: 'collrkkl@nic.in',
    ),
  ],
);

ComplaintState _state({bool closed = false, int? waiting}) => ComplaintState(
      id: 'c1',
      lane: ComplaintLane.self,
      severity: ComplaintSeverity.serious,
      status: closed ? 'RESOLVED' : 'UNDER_REVIEW',
      isClosed: closed,
      waitingDays: waiting,
      closedReason: closed ? 'Fixed the next week' : null,
      events: [
        ComplaintEvent(
          id: '1', author: ComplaintAuthor.member, authorName: 'Arun Kumar',
          type: 'CALLED', callOutcome: CallOutcome.promised,
          authorityLabel: 'Assistant Engineer — Street Lighting',
          at: DateTime(2026, 8, 1),
        ),
        ComplaintEvent(
          id: '2', author: ComplaintAuthor.member, authorName: 'Arun Kumar',
          type: 'DRAFTED', authorityLabel: 'Assistant Engineer — Street Lighting',
          at: DateTime(2026, 8, 5),
        ),
        ComplaintEvent(
          id: '3', author: ComplaintAuthor.member, authorName: 'Arun Kumar',
          type: 'SENT', authorityLabel: 'Assistant Engineer — Street Lighting',
          at: DateTime(2026, 8, 5),
        ),
        ComplaintEvent(
          id: '4', author: ComplaintAuthor.club, type: 'FYC_FORWARDED',
          authorityLabel: 'Executive Engineer, TWAD', at: DateTime(2026, 8, 6),
        ),
      ],
    );

const _draft = ComplaintDraft(
  toLabel: 'Assistant Engineer — Street Lighting, Nagercoil Corporation',
  toEmail: 'ae.light@nagercoil.gov.in',
  subject: 'Street light not working at Vadasery bus stand',
  body: 'To: Assistant Engineer — Street Lighting, Nagercoil Corporation\n\n'
      'Sir / Madam,\n\n'
      'The street light opposite Vadasery bus stand has been dead for three '
      'weeks. The stretch is used by schoolchildren in the early morning.\n\n'
      'I spoke to the Assistant Engineer on 1 August 2026, who said it would '
      'be attended to. There has been no action since.\n\n'
      'Location:  Vadasery bus stand\n'
      '           https://www.google.com/maps/search/?api=1&query=8.1833,77.4119\n'
      'Reported:  2026-08-07\n'
      'Reference: F3DD5504\n\n'
      'Arun Kumar\n+91 98400 00000',
  cc: ['commr.nagarcoil@tn.gov.in'],
  bcc: ['complaints@fyc.local'],
  aiWritten: true,
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');

    // Without a real font every glyph renders as a filled box, which is fine
    // for layout and useless for judging whether a screen reads well. Load the
    // app's actual typeface so these are worth looking at.
    for (final family in ['Plus Jakarta Sans', 'Noto Sans Tamil']) {
      final file = family == 'Plus Jakarta Sans'
          ? 'assets/fonts/PlusJakartaSans-400.ttf'
          : 'assets/fonts/NotoSansTamil-400.ttf';
      final loader = FontLoader(family)
        ..addFont(File(file).readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
    final bold = FontLoader('Plus Jakarta Sans')
      ..addFont(File('assets/fonts/PlusJakartaSans-700.ttf')
          .readAsBytes()
          .then((b) => b.buffer.asByteData()));
    await bold.load();
  });

  testWidgets('ladder — light', (t) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2.0;
    await t.pumpWidget(_frame(LadderList(ladder: _ladder, onCalled: (_) {}, onWrite: (_) {})));
    await _shoot(t, '01_ladder_light');
  });

  testWidgets('ladder — dark', (t) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2.0;
    await t.pumpWidget(_frame(LadderList(ladder: _ladder, onCalled: (_) {}, onWrite: (_) {}),
        brightness: Brightness.dark));
    await _shoot(t, '02_ladder_dark');
  });

  testWidgets('timeline — waiting', (t) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2.0;
    await t.pumpWidget(_frame(ComplaintTimeline(state: _state(waiting: 12))));
    await _shoot(t, '03_timeline_waiting');
  });

  testWidgets('timeline — closed', (t) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2.0;
    await t.pumpWidget(_frame(ComplaintTimeline(state: _state(closed: true))));
    await _shoot(t, '04_timeline_closed');
  });

  testWidgets('send sheet', (t) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2.0;
    await t.pumpWidget(_frame(SendLetterSheet(
      draft: _draft, onSentConfirmed: () {}, onBccChanged: (_) {},
    )));
    await _shoot(t, '05_send_sheet');
  });
}
